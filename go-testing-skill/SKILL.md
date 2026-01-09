---
name: go-testing-skill
description: Testing patterns for Go including table-driven tests, mocking with gomock, HTTP handler tests, integration tests, test helpers, fixtures, and benchmarks.
---

# Go Testing Patterns

Testing strategies and patterns for Go.

## Topics Covered

- Table-driven tests
- Mocking with gomock
- HTTP handler tests (Gin)
- Integration tests
- Test helpers & fixtures
- Docker Compose for tests
- Benchmarks
- Coverage

## Quick Commands

```bash
go test ./...                           # All tests
go test -v ./...                        # Verbose
go test -race ./...                     # Race detection
go test -cover ./...                    # Coverage
go test -tags=integration ./...         # Integration tests
go test -bench=. ./...                  # Benchmarks

# Generate mocks
mockgen -source=repository.go -destination=mock/repository_mock.go
```

## Reference Files

- **Testing Patterns**: [references/testing-patterns.md](references/testing-patterns.md)

## Related Skills

- **go-backend-skill** - Go conventions, API design
- **go-database-skill** - Database patterns
- **go-patterns-skill** - Design patterns
