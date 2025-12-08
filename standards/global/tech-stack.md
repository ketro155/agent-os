# Tech Stack

## Context

Global tech stack defaults for Agent OS projects. Override in project-specific `.agent-os/product/tech-stack.md`.

## Default Stack

### Backend
- **Framework**: Ruby on Rails 8.0+ / Node.js with Express/Fastify
- **Language**: Ruby 3.2+ / TypeScript 5.0+
- **Database**: PostgreSQL 17+
- **ORM**: Active Record / Prisma / Drizzle
- **Cache**: Redis (optional)

### Frontend
- **Framework**: React 18+ / Next.js 14+
- **Language**: TypeScript 5.0+
- **Build Tool**: Vite / Next.js built-in
- **CSS Framework**: TailwindCSS 4.0+
- **State Management**: React Query + Zustand

### Development
- **Package Manager**: npm / pnpm
- **Node Version**: 22 LTS
- **Testing**: Jest / Vitest + Testing Library
- **Linting**: ESLint + Prettier

### Infrastructure
- **Hosting**: Vercel / Digital Ocean / AWS
- **Database Hosting**: Managed PostgreSQL
- **Asset Storage**: S3-compatible storage
- **CDN**: CloudFront / Cloudflare
- **CI/CD**: GitHub Actions

## Version Guidelines

### Semantic Versioning
- Use exact versions in production
- Use `^` for compatible updates in development
- Lock versions after stability testing
- Update dependencies monthly

### Supported Versions
- Always use LTS versions for Node.js
- Stay within 1 major version of latest for frameworks
- Security patches applied immediately
- Major upgrades planned quarterly

## Stack Selection Criteria

When selecting technologies:
1. **Community Support**: Large, active community
2. **Documentation**: Comprehensive, up-to-date docs
3. **Maintenance**: Active development, regular releases
4. **Compatibility**: Works with existing stack
5. **Team Familiarity**: Consider learning curve

## Project-Specific Overrides

Create `.agent-os/product/tech-stack.md` to override defaults:

```markdown
# Project Tech Stack

## Overrides from Global Defaults

- **Framework**: Next.js 14 (instead of React + Vite)
- **Database**: MySQL 8 (instead of PostgreSQL)
- **Hosting**: AWS ECS (instead of Vercel)

## Additional Technologies

- **Auth**: Auth0
- **Email**: SendGrid
- **Search**: Elasticsearch
```
