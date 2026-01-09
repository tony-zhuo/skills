---
name: go-effective-skill
description: Official Go idioms and best practices from Effective Go. Covers naming conventions, control structures, functions, data structures, interfaces, concurrency patterns, and error handling the Go way.
---

# Effective Go

Official Go idioms and best practices based on [Effective Go](https://go.dev/doc/effective_go).

> To write Go well, it's important to understand its properties and idioms.

## Reference Files

- **Effective Go**: [references/effective-go.md](references/effective-go.md) - Complete guide covering:
  - Formatting (gofmt)
  - Naming conventions (packages, getters, interfaces, MixedCaps)
  - Control structures (if, for, switch, type switch)
  - Functions (multiple returns, named results, defer)
  - Data (new vs make, slices, maps)
  - Initialization (constants, iota, init)
  - Methods (pointer vs value receivers)
  - Interfaces (design, embedding, type assertions)
  - Concurrency (goroutines, channels, share by communicating)
  - Errors (error interface, panic, recover)

## Key Principles

1. **gofmt** - Let the machine handle formatting
2. **Naming** - Short, concise, no underscores, MixedCaps
3. **Interfaces** - Small, one or two methods, -er suffix
4. **Errors** - Return errors, don't panic
5. **Concurrency** - Share memory by communicating, not vice versa

## Related Skills

- **go-backend-skill** - API design, middleware patterns
- **go-database-skill** - Database patterns with GORM
- **go-patterns-skill** - Design patterns
- **go-testing-skill** - Testing patterns
