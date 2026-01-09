# Go Conventions

## Naming

### Variables & Functions

```go
// unexported: camelCase
var userID string
func getUserByID(id string) {}

// exported: PascalCase  
var MaxRetries = 3
func GetUserByID(id string) {}

// Acronyms: consistent casing
userID, httpClient, apiURL  // not userId, HttpClient
```

### Interfaces

```go
// Single method: verb + "er"
type Reader interface { Read(p []byte) (n int, err error) }
type Validator interface { Validate() error }

// Multiple methods: descriptive noun
type UserRepository interface {
    FindByID(ctx context.Context, id string) (*User, error)
    Create(ctx context.Context, user *User) error
}
```

### Packages

```go
// lowercase, single word, no underscores
package user    // good
package order   // good
package userservice  // avoid - use user
package user_service // bad
```

### Constructors

```go
func NewUserService(repo UserRepository) *UserService {}
func NewClient(opts ...Option) *Client {}
```

## Error Handling

### Wrapping Errors

```go
if err := doSomething(); err != nil {
    return fmt.Errorf("do something: %w", err)
}

// With context
if err := db.QueryRow(query, id).Scan(&user); err != nil {
    return fmt.Errorf("query user id=%s: %w", id, err)
}
```

### Sentinel Errors

```go
var (
    ErrNotFound      = errors.New("not found")
    ErrUnauthorized  = errors.New("unauthorized")
    ErrAlreadyExists = errors.New("already exists")
    ErrInvalidInput  = errors.New("invalid input")
)
```

### Custom Error Types

```go
type NotFoundError struct {
    Resource string
    ID       string
}

func (e *NotFoundError) Error() string {
    return fmt.Sprintf("%s %s not found", e.Resource, e.ID)
}
```

### Error Checking

```go
// Check sentinel
if errors.Is(err, ErrNotFound) {
    // handle not found
}

// Check type
var notFound *NotFoundError
if errors.As(err, &notFound) {
    // handle with access to notFound.Resource, notFound.ID
}
```

## Context

### Rules

- First parameter, always named `ctx`
- Never store in structs
- Pass down the call chain

```go
func (s *Service) GetUser(ctx context.Context, id string) (*User, error) {
    return s.repo.FindByID(ctx, id)
}
```

### Context Values

```go
type contextKey string

const userIDKey contextKey = "userID"

func WithUserID(ctx context.Context, id string) context.Context {
    return context.WithValue(ctx, userIDKey, id)
}

func UserIDFromContext(ctx context.Context) (string, bool) {
    id, ok := ctx.Value(userIDKey).(string)
    return id, ok
}
```

### Timeout

```go
ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
defer cancel()

result, err := s.client.Call(ctx, req)
```

## Struct Tags

```go
type User struct {
    ID        string    `json:"id" db:"id"`
    Email     string    `json:"email" db:"email"`
    Name      string    `json:"name" db:"name"`
    CreatedAt time.Time `json:"created_at" db:"created_at"`
}

// Validation (gin binding / go-playground/validator)
type CreateUserRequest struct {
    Email    string `json:"email" binding:"required,email"`
    Name     string `json:"name" binding:"required,min=2,max=100"`
    Password string `json:"password" binding:"required,min=8"`
}
```

## Logging (slog)

```go
import "log/slog"

// Setup
logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
    Level: slog.LevelInfo,
}))
slog.SetDefault(logger)

// Usage
slog.Info("user created",
    slog.String("user_id", user.ID),
    slog.String("email", user.Email),
)

slog.Error("failed to create user",
    slog.String("error", err.Error()),
    slog.String("email", req.Email),
)
```

### Log Levels

| Level | Use Case |
|-------|----------|
| Debug | Development, detailed flow |
| Info | Normal operations, state changes |
| Warn | Unexpected but handled |
| Error | Failures requiring attention |

## Concurrency

### errgroup

```go
import "golang.org/x/sync/errgroup"

func ProcessItems(ctx context.Context, items []Item) error {
    g, ctx := errgroup.WithContext(ctx)
    
    for _, item := range items {
        item := item // capture
        g.Go(func() error {
            return processItem(ctx, item)
        })
    }
    
    return g.Wait()
}
```

### sync.Pool

```go
var bufferPool = sync.Pool{
    New: func() interface{} {
        return new(bytes.Buffer)
    },
}

buf := bufferPool.Get().(*bytes.Buffer)
defer func() {
    buf.Reset()
    bufferPool.Put(buf)
}()
```

## Performance Tips

```go
// Pre-allocate slices
users := make([]User, 0, len(ids))

// strings.Builder for concatenation
var b strings.Builder
for _, s := range strs {
    b.WriteString(s)
}
result := b.String()

// Avoid defer in hot loops
for _, item := range items {
    process(item)
    cleanup() // explicit, not defer
}
```
