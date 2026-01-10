#!/usr/bin/env ts-node
/**
 * AST-based Verification System for Agent OS v4.9.0
 * 
 * Provides accurate TypeScript/JavaScript export and function verification
 * using the TypeScript compiler API instead of brittle grep patterns.
 * 
 * Features:
 * - Export detection (named, default, re-exports)
 * - Function detection (declarations, expressions, arrow functions)
 * - Type detection (interfaces, type aliases, enums)
 * - File hash caching for performance
 */

import * as ts from 'typescript';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';

// ============================================================================
// Types
// ============================================================================

export interface VerificationResult {
  verified: boolean;
  exports: string[];
  functions: string[];
  types: string[];
  errors: string[];
}

export interface CachedVerification {
  hash: string;
  timestamp: string;
  result: VerificationResult;
}

export interface VerifyOptions {
  useCache?: boolean;
  cacheDir?: string;
}

// ============================================================================
// Core Verification Functions
// ============================================================================

/**
 * Get file hash for cache validation
 */
export function getFileHash(filePath: string): string {
  if (!fs.existsSync(filePath)) {
    throw new Error(`File not found: ${filePath}`);
  }
  const content = fs.readFileSync(filePath, 'utf-8');
  return crypto.createHash('sha256').update(content).digest('hex').slice(0, 16);
}

/**
 * Verify exports in a TypeScript/JavaScript file using AST
 */
export function verifyExports(filePath: string): VerificationResult {
  const result: VerificationResult = {
    verified: false,
    exports: [],
    functions: [],
    types: [],
    errors: []
  };

  if (!fs.existsSync(filePath)) {
    result.errors.push(`File not found: ${filePath}`);
    return result;
  }

  const fileContent = fs.readFileSync(filePath, 'utf-8');
  const sourceFile = ts.createSourceFile(
    filePath,
    fileContent,
    ts.ScriptTarget.Latest,
    true,
    filePath.endsWith('.tsx') ? ts.ScriptKind.TSX : 
    filePath.endsWith('.ts') ? ts.ScriptKind.TS :
    filePath.endsWith('.jsx') ? ts.ScriptKind.JSX : ts.ScriptKind.JS
  );

  // Walk the AST
  function visit(node: ts.Node): void {
    // Export declarations: export const/let/var, export function, export class
    if (ts.isExportDeclaration(node)) {
      // export { name1, name2 } or export * from 'module'
      if (node.exportClause && ts.isNamedExports(node.exportClause)) {
        node.exportClause.elements.forEach(element => {
          result.exports.push(element.name.text);
        });
      }
    }
    
    // Variable statement with export modifier: export const foo = ...
    if (ts.isVariableStatement(node)) {
      const hasExport = node.modifiers?.some(m => m.kind === ts.SyntaxKind.ExportKeyword);
      if (hasExport) {
        node.declarationList.declarations.forEach(decl => {
          if (ts.isIdentifier(decl.name)) {
            result.exports.push(decl.name.text);
            // Check if it's a function expression
            if (decl.initializer && 
                (ts.isFunctionExpression(decl.initializer) || 
                 ts.isArrowFunction(decl.initializer))) {
              result.functions.push(decl.name.text);
            }
          }
        });
      }
    }
    
    // Function declaration with export: export function foo() {}
    if (ts.isFunctionDeclaration(node)) {
      const hasExport = node.modifiers?.some(m => m.kind === ts.SyntaxKind.ExportKeyword);
      if (node.name) {
        if (hasExport) {
          result.exports.push(node.name.text);
        }
        result.functions.push(node.name.text);
      }
    }
    
    // Class declaration with export
    if (ts.isClassDeclaration(node)) {
      const hasExport = node.modifiers?.some(m => m.kind === ts.SyntaxKind.ExportKeyword);
      if (hasExport && node.name) {
        result.exports.push(node.name.text);
      }
    }
    
    // Interface declarations
    if (ts.isInterfaceDeclaration(node)) {
      const hasExport = node.modifiers?.some(m => m.kind === ts.SyntaxKind.ExportKeyword);
      if (hasExport) {
        result.exports.push(node.name.text);
      }
      result.types.push(node.name.text);
    }
    
    // Type alias declarations
    if (ts.isTypeAliasDeclaration(node)) {
      const hasExport = node.modifiers?.some(m => m.kind === ts.SyntaxKind.ExportKeyword);
      if (hasExport) {
        result.exports.push(node.name.text);
      }
      result.types.push(node.name.text);
    }
    
    // Enum declarations
    if (ts.isEnumDeclaration(node)) {
      const hasExport = node.modifiers?.some(m => m.kind === ts.SyntaxKind.ExportKeyword);
      if (hasExport) {
        result.exports.push(node.name.text);
      }
      result.types.push(node.name.text);
    }
    
    // Default export
    if (node.kind === ts.SyntaxKind.ExportAssignment) {
      result.exports.push('default');
    }
    
    ts.forEachChild(node, visit);
  }

  visit(sourceFile);
  result.verified = result.errors.length === 0;
  return result;
}

/**
 * Verify with caching support
 */
export function verifyWithCache(
  filePath: string,
  options: VerifyOptions = {}
): VerificationResult {
  const { useCache = true, cacheDir = '.agent-os/cache/verification' } = options;
  
  if (!useCache) {
    return verifyExports(filePath);
  }
  
  const absPath = path.resolve(filePath);
  const cacheKey = crypto.createHash('md5').update(absPath).digest('hex');
  const cachePath = path.join(cacheDir, `${cacheKey}.json`);
  
  // Try to load from cache
  if (fs.existsSync(cachePath)) {
    try {
      const cached: CachedVerification = JSON.parse(fs.readFileSync(cachePath, 'utf-8'));
      const currentHash = getFileHash(filePath);
      
      if (cached.hash === currentHash) {
        // Cache hit - file unchanged
        return cached.result;
      }
    } catch (e) {
      // Cache corrupted, continue with fresh verification
    }
  }
  
  // Cache miss or stale - verify and cache
  const result = verifyExports(filePath);
  
  try {
    fs.mkdirSync(cacheDir, { recursive: true });
    const cacheData: CachedVerification = {
      hash: getFileHash(filePath),
      timestamp: new Date().toISOString(),
      result
    };
    fs.writeFileSync(cachePath, JSON.stringify(cacheData, null, 2));
  } catch (e) {
    // Cache write failed, continue without caching
    console.warn(`Failed to write verification cache: ${e}`);
  }
  
  return result;
}

/**
 * Verify a specific export exists in a file
 */
export function verifyExportExists(filePath: string, exportName: string): boolean {
  const result = verifyWithCache(filePath);
  return result.exports.includes(exportName);
}

/**
 * Verify a specific function exists in a file
 */
export function verifyFunctionExists(filePath: string, functionName: string): boolean {
  const result = verifyWithCache(filePath);
  return result.functions.includes(functionName);
}

/**
 * Batch verify multiple exports across multiple files
 */
export function batchVerifyExports(
  claims: Array<{ file: string; exportName: string }>
): Array<{ file: string; exportName: string; exists: boolean; error?: string }> {
  return claims.map(claim => {
    try {
      const exists = verifyExportExists(claim.file, claim.exportName);
      return { ...claim, exists };
    } catch (e) {
      return { ...claim, exists: false, error: String(e) };
    }
  });
}

/**
 * Clear verification cache for a file or all files
 */
export function clearCache(
  filePath?: string,
  cacheDir: string = '.agent-os/cache/verification'
): void {
  if (!fs.existsSync(cacheDir)) {
    return;
  }
  
  if (filePath) {
    const absPath = path.resolve(filePath);
    const cacheKey = crypto.createHash('md5').update(absPath).digest('hex');
    const cachePath = path.join(cacheDir, `${cacheKey}.json`);
    if (fs.existsSync(cachePath)) {
      fs.unlinkSync(cachePath);
    }
  } else {
    // Clear all cache files
    const files = fs.readdirSync(cacheDir);
    files.forEach(file => {
      if (file.endsWith('.json')) {
        fs.unlinkSync(path.join(cacheDir, file));
      }
    });
  }
}

// ============================================================================
// CLI Interface
// ============================================================================

if (require.main === module) {
  const args = process.argv.slice(2);
  const command = args[0];
  
  if (command === 'verify' && args[1]) {
    const result = verifyWithCache(args[1]);
    console.log(JSON.stringify(result, null, 2));
    process.exit(result.verified ? 0 : 1);
  }
  
  if (command === 'check-export' && args[1] && args[2]) {
    const exists = verifyExportExists(args[1], args[2]);
    console.log(JSON.stringify({ file: args[1], export: args[2], exists }));
    process.exit(exists ? 0 : 1);
  }
  
  if (command === 'check-function' && args[1] && args[2]) {
    const exists = verifyFunctionExists(args[1], args[2]);
    console.log(JSON.stringify({ file: args[1], function: args[2], exists }));
    process.exit(exists ? 0 : 1);
  }
  
  if (command === 'hash' && args[1]) {
    console.log(getFileHash(args[1]));
    process.exit(0);
  }
  
  if (command === 'clear-cache') {
    clearCache(args[1]);
    console.log('Cache cleared');
    process.exit(0);
  }
  
  console.log(`
AST Verification System v4.9.0

Usage:
  ts-node ast-verify.ts verify <file>           Verify exports/functions in file
  ts-node ast-verify.ts check-export <file> <name>  Check if export exists
  ts-node ast-verify.ts check-function <file> <name>  Check if function exists
  ts-node ast-verify.ts hash <file>             Get file hash
  ts-node ast-verify.ts clear-cache [file]      Clear verification cache
`);
  process.exit(1);
}
