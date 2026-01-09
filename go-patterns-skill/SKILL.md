---
name: go-patterns-skill
description: Comprehensive design patterns for Go including all GoF patterns adapted for Go, plus Go-specific concurrency patterns like Circuit Breaker, Retry, Worker Pool, and Semaphore. Backed by concrete examples from the golang-design-pattern repository.
---

# Go Design Patterns

Complete design patterns reference for Go.

## Patterns Included

### Creational
- Simple Factory
- Factory / Factory Method
- Abstract Factory
- Builder
- Options Pattern (Functional Options)
- Singleton (sync.Once)
- Prototype

### Structural
- Adapter
- Decorator
- Facade
- Proxy
- Composite
- Flyweight
- Bridge

### Behavioral
- Strategy
- Observer (Event Bus / Pub-Sub)
- Command (with Undo/Redo)
- Chain of Responsibility
- State
- Template Method
- Visitor
- Mediator
- Iterator
- Memento
- Interpreter

### Go-Specific Concurrency
- Circuit Breaker
- Retry with Backoff (Exponential + Jitter)
- Worker Pool
- Semaphore
- Fan-Out / Fan-In
- Rate-Limited Pool
- Middleware Pattern

## Reference Files

- **Design Patterns**: [references/design-patterns.md](references/design-patterns.md)

## External Repository

- Core GoF pattern examples are mirrored from: `https://github.com/tony-zhuo/golang-design-pattern`

## Related Skills

- **go-backend-skill** - Go conventions, API design
- **go-database-skill** - Database patterns
- **go-testing-skill** - Testing patterns
