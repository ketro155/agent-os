#!/bin/bash
# Automatic codebase indexing and caching

INDEX_FILE=".agent-os/cache/index.json"
CACHE_TTL=3600  # 1 hour

needs_reindex() {
  if [ ! -f "$INDEX_FILE" ]; then
    return 0
  fi
  
  # Check if any files newer than index
  if [ $(find . -newer "$INDEX_FILE" -type f \( -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.md" \) | wc -l) -gt 0 ]; then
    return 0
  fi
  
  # Check if index is older than TTL
  if [ $(find "$INDEX_FILE" -mmin +60 | wc -l) -gt 0 ]; then
    return 0
  fi
  
  return 1
}

build_index() {
  echo "Building codebase index..."
  
  local index_data='{'
  index_data+='"indexed": "'$(date)'",'
  index_data+='"files": {'
  
  # Index JavaScript/TypeScript files
  for file in $(find . -type f \( -name "*.js" -o -name "*.ts" \) -not -path "*/node_modules/*" 2>/dev/null); do
    local functions=$(grep -E "^(export )?(async )?(function |const |let |var )[a-zA-Z_][a-zA-Z0-9_]* =" "$file" | head -5)
    local classes=$(grep -E "^(export )?(class |interface )" "$file" | head -5)
    
    if [ -n "$functions" ] || [ -n "$classes" ]; then
      index_data+='"'$file'": {'
      index_data+='"type": "code",'
      index_data+='"language": "'${file##*.}'",'
      index_data+='"size": '$(wc -c < "$file")','
      index_data+='"modified": "'$(date -r "$file" 2>/dev/null || date)'"'
      index_data+='},'
    fi
  done
  
  # Index Python files
  for file in $(find . -type f -name "*.py" -not -path "*/venv/*" -not -path "*/__pycache__/*" 2>/dev/null); do
    local functions=$(grep -E "^def " "$file" | head -5)
    local classes=$(grep -E "^class " "$file" | head -5)
    
    if [ -n "$functions" ] || [ -n "$classes" ]; then
      index_data+='"'$file'": {'
      index_data+='"type": "code",'
      index_data+='"language": "python",'
      index_data+='"size": '$(wc -c < "$file")','
      index_data+='"modified": "'$(date -r "$file" 2>/dev/null || date)'"'
      index_data+='},'
    fi
  done
  
  # Index markdown files (commands and specs)
  for file in $(find . -type f -name "*.md" -not -path "*/.agent-os/*" 2>/dev/null); do
    if grep -q "^# \|^## Task\|^## Specification" "$file"; then
      index_data+='"'$file'": {'
      index_data+='"type": "documentation",'
      index_data+='"language": "markdown",'
      index_data+='"size": '$(wc -c < "$file")','
      index_data+='"modified": "'$(date -r "$file" 2>/dev/null || date)'"'
      index_data+='},'
    fi
  done
  
  # Remove trailing comma and close JSON
  index_data=${index_data%,}
  index_data+='}}'
  
  echo "$index_data" | jq . > "$INDEX_FILE"
  echo "Index built: $(echo "$index_data" | jq '.files | length') files indexed"
}

search_index() {
  local query="$1"
  
  if [ ! -f "$INDEX_FILE" ]; then
    echo "No index found. Building..."
    build_index
  fi
  
  # Search in index
  jq --arg q "$query" '.files | to_entries | .[] | select(.key | contains($q))' "$INDEX_FILE"
}

# Main execution
main() {
  case "${1:-check}" in
    "build")
      build_index
      ;;
    "search")
      search_index "${2:-}"
      ;;
    "check")
      if needs_reindex; then
        build_index
      else
        echo "Index is up to date"
      fi
      ;;
    *)
      echo "Usage: $0 {build|search|check} [query]"
      exit 1
      ;;
  esac
}

# Hook event handling
if [ -n "$HOOK_EVENT" ]; then
  case "$HOOK_EVENT" in
    "pre-tool-use")
      if needs_reindex; then
        build_index
      fi
      ;;
    "post-command")
      # Force reindex after command execution
      build_index
      ;;
  esac
fi

# Execute if not sourced
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi