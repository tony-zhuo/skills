---
name: go-database-skill
description: Database patterns for Go using GORM (MySQL 8+, PostgreSQL 17+) and Redis 7+. Includes connection setup, transactions, atomic operations, Lua scripts, N+1 solutions (Preload), soft delete, and optimistic locking.
---

# Go Database Patterns

Database and cache patterns for Go backend using GORM.

## Supported Databases

| Database | Version | Package |
|----------|---------|---------|
| PostgreSQL | 17+ | `gorm.io/driver/postgres` |
| MySQL | 8+ | `gorm.io/driver/mysql` |
| Redis | 7+ | `github.com/redis/go-redis/v9` |

## Reference Files

- **SQL Patterns (GORM)**: [references/sql-patterns.md](references/sql-patterns.md) - Connection, model definition, queries, transactions, Preload (N+1), soft delete, optimistic locking, repository pattern
- **Redis Patterns**: [references/redis-patterns.md](references/redis-patterns.md) - Cache, rate limiting, distributed lock, Lua scripts for atomic operations

## Related Skills

- **go-backend-skill** - Go conventions, API design
- **go-patterns-skill** - Design patterns
- **go-testing-skill** - Testing patterns
