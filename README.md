# Claude Code Skills

A collection of development skills for [Claude Code](https://claude.ai/claude-code).

## Available Skills

### Go
- **go-backend-skill** - Go backend development essentials (naming, error handling, context, logging, REST API with Gin)
- **go-database-skill** - Database patterns using GORM (MySQL, PostgreSQL) and Redis
- **go-effective-skill** - Official Go idioms from Effective Go
- **go-patterns-skill** - GoF patterns + Go-specific concurrency patterns
- **go-testing-skill** - Table-driven tests, mocking, HTTP handler tests

### Swift
- **swift-ios-skill** - iOS development patterns (MVVM/MVC, SwiftUI/UIKit, navigation, networking, testing)
- **swift-macos-skill** - macOS development patterns (window management, menu bar apps, screen capture, sandboxing, AppKit)

### General
- **tutorial-mode** - Interactive tutorial mode for step-by-step project development and code understanding

## Installation

### Install all skills
```bash
make install-all
```

### Install a specific skill
```bash
make install SKILL=go-backend-skill
```

### View available skills
```bash
make install
```

Skills are installed to `~/.claude/skills/`.
