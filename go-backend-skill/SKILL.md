---
name: go-backend-skill
description: Go backend development essentials covering naming conventions, error handling, context usage, logging, and REST API design with Gin. Use as the foundation for any Go backend project.
---

# Go Backend Essentials

Core patterns for Go backend development.

## Topics Covered

### Go Conventions
- Naming (variables, interfaces, packages)
- Error handling (wrapping, sentinel, custom types)
- Context usage
- Struct tags
- Logging (slog)
- Concurrency basics (errgroup, sync.Pool)

### API Design
- RESTful URL design
- Response formats (success, error, pagination)
- HTTP status codes
- Request validation (Gin binding)
- Response helpers
- Middleware (auth, request ID, logger, rate limiter, CORS)
- Graceful shutdown

## Reference Files

- **Go Conventions**: [references/go-conventions.md](references/go-conventions.md)
- **API Design**: [references/api-design.md](references/api-design.md)

## Related Skills

- **go-database-skill** - MySQL, PostgreSQL, Redis, transactions, Lua scripts
- **go-patterns-skill** - Factory, Builder, Adapter, Circuit Breaker, Worker Pool
- **go-testing-skill** - Table-driven tests, mocking, integration tests
