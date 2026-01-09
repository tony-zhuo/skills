# Testing Patterns

## Test Commands

```bash
go test ./...                           # All tests
go test -v ./...                        # Verbose
go test -run TestFuncName ./...         # Specific test
go test -race ./...                     # Race detection
go test -cover ./...                    # Show coverage
go test -coverprofile=coverage.out ./...  # Coverage file
go tool cover -html=coverage.out        # View coverage

go test -tags=integration ./...         # Integration tests
go test -bench=. ./...                  # Benchmarks
go test -short ./...                    # Skip long tests
```

## Table-Driven Tests

```go
func TestAdd(t *testing.T) {
    tests := []struct {
        name     string
        a, b     int
        expected int
    }{
        {"positive", 2, 3, 5},
        {"negative", -1, -2, -3},
        {"zero", 0, 0, 0},
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := Add(tt.a, tt.b)
            if got != tt.expected {
                t.Errorf("Add(%d, %d) = %d; want %d", tt.a, tt.b, got, tt.expected)
            }
        })
    }
}
```

## Table-Driven with Mock

```go
func TestUserService_GetByID(t *testing.T) {
    tests := []struct {
        name      string
        id        string
        mockSetup func(*MockUserRepository)
        want      *User
        wantErr   bool
    }{
        {
            name: "found",
            id:   "123",
            mockSetup: func(m *MockUserRepository) {
                m.EXPECT().
                    FindByID(gomock.Any(), "123").
                    Return(&User{ID: "123", Name: "John"}, nil)
            },
            want: &User{ID: "123", Name: "John"},
        },
        {
            name: "not found",
            id:   "999",
            mockSetup: func(m *MockUserRepository) {
                m.EXPECT().
                    FindByID(gomock.Any(), "999").
                    Return(nil, nil)
            },
            wantErr: true,
        },
        {
            name: "db error",
            id:   "456",
            mockSetup: func(m *MockUserRepository) {
                m.EXPECT().
                    FindByID(gomock.Any(), "456").
                    Return(nil, errors.New("connection refused"))
            },
            wantErr: true,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            ctrl := gomock.NewController(t)
            defer ctrl.Finish()
            
            mockRepo := NewMockUserRepository(ctrl)
            tt.mockSetup(mockRepo)
            
            svc := NewUserService(mockRepo)
            got, err := svc.GetByID(context.Background(), tt.id)
            
            if tt.wantErr {
                assert.Error(t, err)
                return
            }
            
            assert.NoError(t, err)
            assert.Equal(t, tt.want, got)
        })
    }
}
```

## Mock Generation (gomock)

```bash
# Install
go install go.uber.org/mock/mockgen@latest

# Generate from interface file
mockgen -source=repository.go -destination=mock/repository_mock.go -package=mock

# Generate from package
mockgen -destination=mock/repository_mock.go -package=mock . UserRepository
```

### go:generate Directive

```go
//go:generate mockgen -source=repository.go -destination=mock/repository_mock.go -package=mock

type UserRepository interface {
    FindByID(ctx context.Context, id string) (*User, error)
    Create(ctx context.Context, user *User) error
}
```

## Mock Expectations

```go
// Exact arguments
mock.EXPECT().FindByID(gomock.Any(), "123").Return(&User{}, nil)

// Any arguments
mock.EXPECT().FindByID(gomock.Any(), gomock.Any()).Return(&User{}, nil)

// Times
mock.EXPECT().FindByID(gomock.Any(), "123").Return(&User{}, nil).Times(1)
mock.EXPECT().FindByID(gomock.Any(), "123").Return(&User{}, nil).AnyTimes()

// In order
gomock.InOrder(
    mock.EXPECT().FindByID(gomock.Any(), "1").Return(&User{}, nil),
    mock.EXPECT().FindByID(gomock.Any(), "2").Return(&User{}, nil),
)

// Do (side effects)
mock.EXPECT().Create(gomock.Any(), gomock.Any()).
    Do(func(ctx context.Context, user *User) {
        user.ID = "generated-id"
    }).
    Return(nil)

// DoAndReturn
mock.EXPECT().FindByID(gomock.Any(), gomock.Any()).
    DoAndReturn(func(ctx context.Context, id string) (*User, error) {
        return &User{ID: id, Name: "Generated"}, nil
    })
```

## HTTP Handler Tests (Gin)

```go
func TestGetUser(t *testing.T) {
    ctrl := gomock.NewController(t)
    defer ctrl.Finish()
    
    mockSvc := NewMockUserService(ctrl)
    mockSvc.EXPECT().
        GetByID(gomock.Any(), "123").
        Return(&User{ID: "123", Name: "John"}, nil)
    
    handler := NewUserHandler(mockSvc)
    
    // Setup router
    gin.SetMode(gin.TestMode)
    r := gin.New()
    r.GET("/users/:id", handler.GetUser)
    
    // Create request
    req := httptest.NewRequest(http.MethodGet, "/users/123", nil)
    rec := httptest.NewRecorder()
    
    // Execute
    r.ServeHTTP(rec, req)
    
    // Assert
    assert.Equal(t, http.StatusOK, rec.Code)
    
    var resp map[string]any
    json.Unmarshal(rec.Body.Bytes(), &resp)
    assert.Equal(t, "123", resp["data"].(map[string]any)["id"])
}

func TestCreateUser(t *testing.T) {
    ctrl := gomock.NewController(t)
    mockSvc := NewMockUserService(ctrl)
    mockSvc.EXPECT().
        Create(gomock.Any(), gomock.Any()).
        Return(&User{ID: "new-123"}, nil)
    
    handler := NewUserHandler(mockSvc)
    
    gin.SetMode(gin.TestMode)
    r := gin.New()
    r.POST("/users", handler.CreateUser)
    
    body := `{"email":"test@example.com","name":"Test","password":"password123"}`
    req := httptest.NewRequest(http.MethodPost, "/users", strings.NewReader(body))
    req.Header.Set("Content-Type", "application/json")
    rec := httptest.NewRecorder()
    
    r.ServeHTTP(rec, req)
    
    assert.Equal(t, http.StatusCreated, rec.Code)
}
```

## Test Helpers

```go
// testutil/testutil.go
package testutil

func NewTestDB(t *testing.T) *sql.DB {
    t.Helper()
    
    dsn := os.Getenv("TEST_DATABASE_URL")
    if dsn == "" {
        t.Skip("TEST_DATABASE_URL not set")
    }
    
    db, err := sql.Open("postgres", dsn)
    if err != nil {
        t.Fatalf("failed to connect: %v", err)
    }
    
    t.Cleanup(func() {
        db.Close()
    })
    
    return db
}

func NewTestRedis(t *testing.T) *redis.Client {
    t.Helper()
    
    url := os.Getenv("TEST_REDIS_URL")
    if url == "" {
        t.Skip("TEST_REDIS_URL not set")
    }
    
    opt, _ := redis.ParseURL(url)
    client := redis.NewClient(opt)
    
    t.Cleanup(func() {
        client.FlushDB(context.Background())
        client.Close()
    })
    
    return client
}

func TestContext(t *testing.T) context.Context {
    t.Helper()
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    t.Cleanup(cancel)
    return ctx
}
```

### Test Fixtures

```go
func NewTestUser(overrides ...func(*User)) *User {
    user := &User{
        ID:        uuid.New().String(),
        Email:     fmt.Sprintf("test_%s@example.com", uuid.New().String()[:8]),
        Name:      "Test User",
        Status:    "active",
        CreatedAt: time.Now(),
    }
    
    for _, fn := range overrides {
        fn(user)
    }
    
    return user
}

// Usage
user := NewTestUser(func(u *User) {
    u.Email = "custom@example.com"
    u.Status = "inactive"
})
```

## Integration Tests

```go
//go:build integration

package integration

func TestUserFlow(t *testing.T) {
    db := testutil.NewTestDB(t)
    cache := testutil.NewTestRedis(t)
    ctx := testutil.TestContext(t)
    
    repo := NewUserRepository(db)
    svc := NewUserService(repo, cache)
    
    // Create
    user, err := svc.Create(ctx, &CreateUserRequest{
        Email: "test@example.com",
        Name:  "Test User",
    })
    require.NoError(t, err)
    require.NotEmpty(t, user.ID)
    
    // Get
    got, err := svc.GetByID(ctx, user.ID)
    require.NoError(t, err)
    assert.Equal(t, user.Email, got.Email)
    
    // Update
    newName := "Updated Name"
    err = svc.Update(ctx, user.ID, &UpdateUserRequest{Name: &newName})
    require.NoError(t, err)
    
    got, _ = svc.GetByID(ctx, user.ID)
    assert.Equal(t, "Updated Name", got.Name)
    
    // Delete
    err = svc.Delete(ctx, user.ID)
    require.NoError(t, err)
    
    got, err = svc.GetByID(ctx, user.ID)
    assert.Error(t, err)
}
```

## Docker Compose for Tests

```yaml
# docker-compose.test.yml
services:
  test-postgres:
    image: postgres:17
    environment:
      POSTGRES_USER: test
      POSTGRES_PASSWORD: test
      POSTGRES_DB: testdb
    ports: ["5433:5432"]
    tmpfs: [/var/lib/postgresql/data]

  test-mysql:
    image: mysql:8
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: testdb
      MYSQL_USER: test
      MYSQL_PASSWORD: test
    ports: ["3307:3306"]
    tmpfs: [/var/lib/mysql]

  test-redis:
    image: redis:7
    ports: ["6380:6379"]
```

```bash
# Start
docker-compose -f docker-compose.test.yml up -d

# Run tests
TEST_DATABASE_URL="postgres://test:test@localhost:5433/testdb?sslmode=disable" \
TEST_REDIS_URL="redis://localhost:6380" \
go test -tags=integration ./...

# Stop
docker-compose -f docker-compose.test.yml down -v
```

## Assertions (testify)

```go
import (
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

// assert - continues on failure
assert.Equal(t, expected, actual)
assert.NotEqual(t, unexpected, actual)
assert.Nil(t, value)
assert.NotNil(t, value)
assert.True(t, condition)
assert.False(t, condition)
assert.Error(t, err)
assert.NoError(t, err)
assert.ErrorIs(t, err, ErrNotFound)
assert.ErrorAs(t, err, &notFoundErr)
assert.Contains(t, slice, element)
assert.Len(t, slice, 5)
assert.Empty(t, slice)
assert.JSONEq(t, expectedJSON, actualJSON)

// require - stops on failure (use for setup)
require.NoError(t, err)
require.NotNil(t, value)
```

## Benchmarks

```go
func BenchmarkGetUser(b *testing.B) {
    svc := setupService()
    user := createTestUser()
    ctx := context.Background()
    
    b.ResetTimer()
    
    for i := 0; i < b.N; i++ {
        _, _ = svc.GetByID(ctx, user.ID)
    }
}

func BenchmarkGetUserParallel(b *testing.B) {
    svc := setupService()
    user := createTestUser()
    
    b.RunParallel(func(pb *testing.PB) {
        ctx := context.Background()
        for pb.Next() {
            _, _ = svc.GetByID(ctx, user.ID)
        }
    })
}
```

```bash
go test -bench=. -benchmem ./...
# BenchmarkGetUser-8    500000    3000 ns/op    256 B/op    5 allocs/op
```

## Test Coverage

```bash
# Generate coverage
go test -coverprofile=coverage.out ./...

# View in browser
go tool cover -html=coverage.out

# Check minimum coverage
go test -coverprofile=coverage.out ./... && \
  go tool cover -func=coverage.out | grep total | awk '{print $3}' | \
  awk -F'%' '{if ($1 < 80) exit 1}'
```

## Concurrent Test

```go
func TestConcurrentAccess(t *testing.T) {
    svc := setupService()
    user := createTestUser()
    
    var wg sync.WaitGroup
    errors := make(chan error, 100)
    
    for i := 0; i < 100; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            _, err := svc.GetByID(context.Background(), user.ID)
            if err != nil {
                errors <- err
            }
        }()
    }
    
    wg.Wait()
    close(errors)
    
    for err := range errors {
        t.Errorf("concurrent error: %v", err)
    }
}
```
