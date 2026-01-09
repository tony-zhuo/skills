# API Design Patterns

## RESTful URL Design

```
GET    /api/v1/users              # List
POST   /api/v1/users              # Create
GET    /api/v1/users/{id}         # Get one
PUT    /api/v1/users/{id}         # Full update
PATCH  /api/v1/users/{id}         # Partial update
DELETE /api/v1/users/{id}         # Delete

# Nested resources
GET    /api/v1/users/{id}/orders
POST   /api/v1/users/{id}/orders

# Actions (when CRUD doesn't fit)
POST   /api/v1/users/{id}/verify
POST   /api/v1/orders/{id}/cancel
POST   /api/v1/orders/{id}/refund
```

## Query Parameters

```
# Pagination
?page=1&page_size=20
?cursor=abc123&limit=20

# Filtering
?status=active&role=admin
?created_after=2024-01-01

# Sorting
?sort=created_at&order=desc
?sort=-created_at              # prefix - for desc

# Field selection
?fields=id,name,email

# Search
?q=john
```

## Response Formats

### Success

```json
{
  "data": {
    "id": "usr_123",
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

### List with Pagination

```json
{
  "data": [
    {"id": "usr_123", "name": "John"},
    {"id": "usr_124", "name": "Jane"}
  ],
  "pagination": {
    "page": 1,
    "page_size": 20,
    "total": 150,
    "total_pages": 8
  }
}
```

### Cursor-based Pagination

```json
{
  "data": [...],
  "pagination": {
    "next_cursor": "eyJpZCI6MTIzfQ==",
    "has_more": true
  }
}
```

### Error

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request parameters",
    "details": [
      {"field": "email", "message": "must be a valid email"}
    ]
  }
}
```

## HTTP Status Codes

| Code | Use Case |
|------|----------|
| 200 | Success (GET, PUT, PATCH) |
| 201 | Created (POST) |
| 204 | No Content (DELETE) |
| 400 | Bad Request (malformed JSON) |
| 401 | Unauthorized (no/invalid token) |
| 403 | Forbidden (no permission) |
| 404 | Not Found |
| 409 | Conflict (duplicate, state conflict) |
| 422 | Unprocessable Entity (validation, business rule) |
| 429 | Too Many Requests |
| 500 | Internal Server Error |

## Request Validation (Gin)

```go
// JSON body
type CreateUserRequest struct {
    Email    string `json:"email" binding:"required,email"`
    Name     string `json:"name" binding:"required,min=2,max=100"`
    Password string `json:"password" binding:"required,min=8"`
}

// Query params
type ListUsersQuery struct {
    Page     int    `form:"page" binding:"omitempty,min=1"`
    PageSize int    `form:"page_size" binding:"omitempty,min=1,max=100"`
    Status   string `form:"status" binding:"omitempty,oneof=active inactive"`
}

// URI params
type GetUserURI struct {
    ID string `uri:"id" binding:"required,uuid"`
}

// Usage
var req CreateUserRequest
if err := c.ShouldBindJSON(&req); err != nil { ... }

var query ListUsersQuery
if err := c.ShouldBindQuery(&query); err != nil { ... }

var uri GetUserURI
if err := c.ShouldBindUri(&uri); err != nil { ... }
```

## Response Helpers

```go
func Success(c *gin.Context, data any) {
    c.JSON(http.StatusOK, gin.H{"data": data})
}

func Created(c *gin.Context, data any) {
    c.JSON(http.StatusCreated, gin.H{"data": data})
}

func NoContent(c *gin.Context) {
    c.Status(http.StatusNoContent)
}

func Error(c *gin.Context, status int, code, message string) {
    c.JSON(status, gin.H{
        "error": gin.H{"code": code, "message": message},
    })
}

func SuccessWithPagination(c *gin.Context, data any, page, pageSize, total int) {
    c.JSON(http.StatusOK, gin.H{
        "data": data,
        "pagination": gin.H{
            "page":        page,
            "page_size":   pageSize,
            "total":       total,
            "total_pages": (total + pageSize - 1) / pageSize,
        },
    })
}

func ValidationError(c *gin.Context, err error) {
    var ve validator.ValidationErrors
    if errors.As(err, &ve) {
        details := make([]gin.H, 0, len(ve))
        for _, fe := range ve {
            details = append(details, gin.H{
                "field":   toSnakeCase(fe.Field()),
                "message": formatFieldError(fe),
            })
        }
        c.JSON(http.StatusBadRequest, gin.H{
            "error": gin.H{
                "code":    "VALIDATION_ERROR",
                "message": "Invalid request parameters",
                "details": details,
            },
        })
        return
    }
    Error(c, http.StatusBadRequest, "INVALID_REQUEST", err.Error())
}
```

## Common Middleware Patterns

### Request ID

```go
func RequestID() gin.HandlerFunc {
    return func(c *gin.Context) {
        id := c.GetHeader("X-Request-ID")
        if id == "" {
            id = uuid.New().String()
        }
        c.Set("requestID", id)
        c.Header("X-Request-ID", id)
        c.Next()
    }
}
```

### Logger

```go
func Logger() gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        c.Next()
        
        slog.Info("request",
            slog.String("method", c.Request.Method),
            slog.String("path", c.Request.URL.Path),
            slog.Int("status", c.Writer.Status()),
            slog.Duration("latency", time.Since(start)),
            slog.String("request_id", c.GetString("requestID")),
        )
    }
}
```

### Auth

```go
func Auth(validate func(token string) (*Claims, error)) gin.HandlerFunc {
    return func(c *gin.Context) {
        token := strings.TrimPrefix(c.GetHeader("Authorization"), "Bearer ")
        if token == "" {
            Error(c, http.StatusUnauthorized, "UNAUTHORIZED", "Missing token")
            c.Abort()
            return
        }
        
        claims, err := validate(token)
        if err != nil {
            Error(c, http.StatusUnauthorized, "INVALID_TOKEN", "Invalid token")
            c.Abort()
            return
        }
        
        c.Set("claims", claims)
        c.Set("userID", claims.UserID)
        c.Next()
    }
}
```

### Role Check

```go
func RequireRole(roles ...string) gin.HandlerFunc {
    return func(c *gin.Context) {
        claims, _ := c.Get("claims")
        userClaims := claims.(*Claims)
        
        for _, role := range roles {
            if userClaims.Role == role {
                c.Next()
                return
            }
        }
        
        Error(c, http.StatusForbidden, "FORBIDDEN", "Insufficient permissions")
        c.Abort()
    }
}
```

### Rate Limiter

```go
func RateLimiter(allow func(key string) (bool, error)) gin.HandlerFunc {
    return func(c *gin.Context) {
        key := c.ClientIP()
        if userID := c.GetString("userID"); userID != "" {
            key = "user:" + userID
        }
        
        allowed, err := allow(key)
        if err != nil {
            c.Next() // fail open
            return
        }
        
        if !allowed {
            Error(c, http.StatusTooManyRequests, "RATE_LIMITED", "Too many requests")
            c.Abort()
            return
        }
        
        c.Next()
    }
}
```

### CORS

```go
func CORS() gin.HandlerFunc {
    return func(c *gin.Context) {
        c.Header("Access-Control-Allow-Origin", "*")
        c.Header("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS")
        c.Header("Access-Control-Allow-Headers", "Origin,Content-Type,Authorization,X-Request-ID")
        c.Header("Access-Control-Max-Age", "86400")
        
        if c.Request.Method == "OPTIONS" {
            c.AbortWithStatus(http.StatusNoContent)
            return
        }
        c.Next()
    }
}
```

## Error Mapping Pattern

```go
func mapError(c *gin.Context, err error) {
    var notFound *NotFoundError
    if errors.As(err, &notFound) {
        Error(c, http.StatusNotFound, "NOT_FOUND", err.Error())
        return
    }
    
    if errors.Is(err, ErrUnauthorized) {
        Error(c, http.StatusUnauthorized, "UNAUTHORIZED", err.Error())
        return
    }
    
    if errors.Is(err, ErrAlreadyExists) {
        Error(c, http.StatusConflict, "ALREADY_EXISTS", err.Error())
        return
    }
    
    if errors.Is(err, ErrInvalidInput) {
        Error(c, http.StatusBadRequest, "INVALID_INPUT", err.Error())
        return
    }
    
    // Log unexpected errors
    slog.Error("unexpected error", slog.String("error", err.Error()))
    Error(c, http.StatusInternalServerError, "INTERNAL_ERROR", "Internal server error")
}
```

## Graceful Shutdown

```go
func main() {
    router := setupRouter()
    
    srv := &http.Server{
        Addr:    ":8080",
        Handler: router,
    }
    
    go func() {
        if err := srv.ListenAndServe(); err != http.ErrServerClosed {
            log.Fatal(err)
        }
    }()
    
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit
    
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()
    
    srv.Shutdown(ctx)
}
```
