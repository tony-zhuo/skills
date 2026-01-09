# SQL Patterns (GORM)

Patterns for MySQL 8+ and PostgreSQL 17+ using GORM.

## Connection Setup

### PostgreSQL

```go
import (
    "gorm.io/driver/postgres"
    "gorm.io/gorm"
    "gorm.io/gorm/logger"
)

func NewPostgresDB(dsn string) (*gorm.DB, error) {
    // DSN: host=localhost user=user password=pass dbname=mydb port=5432 sslmode=disable
    db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
        Logger: logger.Default.LogMode(logger.Info),
    })
    if err != nil {
        return nil, fmt.Errorf("connect database: %w", err)
    }
    
    sqlDB, err := db.DB()
    if err != nil {
        return nil, err
    }
    
    sqlDB.SetMaxOpenConns(25)
    sqlDB.SetMaxIdleConns(10)
    sqlDB.SetConnMaxLifetime(5 * time.Minute)
    
    return db, nil
}
```

### MySQL

```go
import (
    "gorm.io/driver/mysql"
    "gorm.io/gorm"
)

func NewMySQLDB(dsn string) (*gorm.DB, error) {
    // DSN: user:pass@tcp(127.0.0.1:3306)/dbname?charset=utf8mb4&parseTime=True&loc=Local
    db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{})
    if err != nil {
        return nil, fmt.Errorf("connect database: %w", err)
    }
    
    sqlDB, err := db.DB()
    if err != nil {
        return nil, err
    }
    
    sqlDB.SetMaxOpenConns(25)
    sqlDB.SetMaxIdleConns(10)
    sqlDB.SetConnMaxLifetime(5 * time.Minute)
    
    return db, nil
}
```

### GORM Config Options

```go
db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
    Logger: logger.Default.LogMode(logger.Info),
    
    // Disable default transaction for single operations (performance)
    SkipDefaultTransaction: true,
    
    // Naming strategy
    NamingStrategy: schema.NamingStrategy{
        TablePrefix:   "",
        SingularTable: true,
        NameReplacer:  nil,
        NoLowerCase:   false,
    },
    
    // Prepared statement cache
    PrepareStmt: true,
    
    // Disable foreign key constraints when migrating
    DisableForeignKeyConstraintWhenMigrating: true,
})
```

## Model Definition

### Basic Model

```go
type User struct {
    ID        string         `gorm:"type:char(36);primaryKey"`
    Email     string         `gorm:"type:varchar(255);uniqueIndex;not null"`
    Name      string         `gorm:"type:varchar(100);not null"`
    Status    string         `gorm:"type:varchar(20);default:'active';not null"`
    CreatedAt time.Time      `gorm:"autoCreateTime"`
    UpdatedAt time.Time      `gorm:"autoUpdateTime"`
    DeletedAt gorm.DeletedAt `gorm:"index"` // Soft delete
}

func (User) TableName() string {
    return "users"
}
```

### With Relationships

```go
type User struct {
    ID        string         `gorm:"type:char(36);primaryKey"`
    Email     string         `gorm:"type:varchar(255);uniqueIndex"`
    Name      string         `gorm:"type:varchar(100)"`
    Profile   *Profile       `gorm:"foreignKey:UserID"`  // Has One
    Orders    []Order        `gorm:"foreignKey:UserID"`  // Has Many
    CreatedAt time.Time
    UpdatedAt time.Time
    DeletedAt gorm.DeletedAt `gorm:"index"`
}

type Order struct {
    ID        string      `gorm:"type:char(36);primaryKey"`
    UserID    string      `gorm:"type:char(36);index"`
    User      User        `gorm:"foreignKey:UserID"`     // Belongs To
    Items     []OrderItem `gorm:"foreignKey:OrderID"`    // Has Many
    Total     float64     `gorm:"type:decimal(10,2)"`
    Status    string      `gorm:"type:varchar(20)"`
    CreatedAt time.Time
}

type OrderItem struct {
    ID        string  `gorm:"type:char(36);primaryKey"`
    OrderID   string  `gorm:"type:char(36);index"`
    ProductID string  `gorm:"type:char(36)"`
    Product   Product `gorm:"foreignKey:ProductID"`
    Quantity  int
    Price     float64 `gorm:"type:decimal(10,2)"`
}
```

### Common GORM Tags

| Tag | Description |
|-----|-------------|
| `primaryKey` | Primary key |
| `uniqueIndex` | Unique index |
| `index` | Normal index |
| `not null` | NOT NULL |
| `default:'value'` | Default value |
| `type:varchar(100)` | Column type |
| `column:col_name` | Custom column name |
| `autoCreateTime` | Auto set on create |
| `autoUpdateTime` | Auto set on update |
| `-` | Ignore field |
| `embedded` | Embed struct |

## Query Patterns

### Find One

```go
var user User

// By primary key
err := db.First(&user, "id = ?", id).Error
if errors.Is(err, gorm.ErrRecordNotFound) {
    return nil, nil
}

// By condition
err := db.Where("email = ?", email).First(&user).Error

// Select specific fields
err := db.Select("id", "email", "name").First(&user, "id = ?", id).Error
```

### Find Multiple

```go
var users []User

// Simple condition
err := db.Where("status = ?", "active").Find(&users).Error

// Multiple conditions
err := db.Where("status = ? AND created_at > ?", "active", lastMonth).Find(&users).Error

// Using struct (zero values ignored)
err := db.Where(&User{Status: "active"}).Find(&users).Error

// Using map (zero values included)
err := db.Where(map[string]interface{}{
    "status": "active",
    "name":   "John",
}).Find(&users).Error

// IN clause
err := db.Where("id IN ?", []string{"id1", "id2", "id3"}).Find(&users).Error

// LIKE
err := db.Where("name LIKE ?", "%john%").Find(&users).Error
```

### Create

```go
user := User{
    ID:    uuid.New().String(),
    Email: "user@example.com",
    Name:  "John Doe",
}
err := db.Create(&user).Error

// Batch create
users := []User{
    {ID: uuid.New().String(), Email: "user1@example.com", Name: "User 1"},
    {ID: uuid.New().String(), Email: "user2@example.com", Name: "User 2"},
}
err := db.Create(&users).Error

// Create in batches (for large datasets)
err := db.CreateInBatches(&users, 100).Error // 100 per batch

// Select specific fields
err := db.Select("ID", "Email", "Name").Create(&user).Error

// Omit fields
err := db.Omit("CreatedAt").Create(&user).Error
```

### Update

```go
// Update single field
err := db.Model(&user).Update("name", "New Name").Error

// Update multiple fields with struct (zero values ignored)
err := db.Model(&user).Updates(User{Name: "New Name", Status: "inactive"}).Error

// Update with map (zero values included)
err := db.Model(&user).Updates(map[string]interface{}{
    "name":   "New Name",
    "status": "",  // Will update to empty string
}).Error

// Update with expression
err := db.Model(&product).Update("stock", gorm.Expr("stock - ?", 1)).Error

// Batch update
err := db.Model(&User{}).Where("status = ?", "inactive").Update("status", "active").Error

// Update selected fields only
err := db.Model(&user).Select("Name", "Status").Updates(user).Error
```

### Delete

```go
// Soft delete (if model has DeletedAt)
err := db.Delete(&user).Error
err := db.Delete(&User{}, "id = ?", id).Error

// Batch delete
err := db.Where("status = ?", "banned").Delete(&User{}).Error

// Hard delete (permanent)
err := db.Unscoped().Delete(&user).Error

// Find soft deleted
var users []User
err := db.Unscoped().Where("deleted_at IS NOT NULL").Find(&users).Error
```

### Raw SQL

```go
var users []User
err := db.Raw("SELECT * FROM users WHERE status = ?", "active").Scan(&users).Error

err := db.Exec("UPDATE users SET status = ? WHERE id = ?", "active", id).Error
```

## Error Detection

```go
// Not found
if errors.Is(err, gorm.ErrRecordNotFound) {
    return nil, ErrNotFound
}

// Duplicate key (PostgreSQL)
import "github.com/jackc/pgx/v5/pgconn"

var pgErr *pgconn.PgError
if errors.As(err, &pgErr) && pgErr.Code == "23505" {
    return nil, ErrDuplicateEmail
}

// Duplicate key (MySQL)
import "github.com/go-sql-driver/mysql"

var mysqlErr *mysql.MySQLError
if errors.As(err, &mysqlErr) && mysqlErr.Number == 1062 {
    return nil, ErrDuplicateEmail
}
```

## Transactions

### Basic Transaction

```go
err := db.Transaction(func(tx *gorm.DB) error {
    if err := tx.Create(&user).Error; err != nil {
        return err // Rollback
    }
    
    if err := tx.Create(&profile).Error; err != nil {
        return err // Rollback
    }
    
    return nil // Commit
})
```

### Multi-Table Atomic Operations

```go
func (s *TransferService) Transfer(ctx context.Context, fromID, toID string, amount decimal.Decimal) error {
    return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
        // 1. Lock source account (SELECT FOR UPDATE)
        var fromAccount Account
        if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
            First(&fromAccount, "id = ?", fromID).Error; err != nil {
            return fmt.Errorf("get source account: %w", err)
        }
        
        // 2. Check balance
        if fromAccount.Balance.LessThan(amount) {
            return ErrInsufficientBalance
        }
        
        // 3. Lock destination account
        var toAccount Account
        if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
            First(&toAccount, "id = ?", toID).Error; err != nil {
            return fmt.Errorf("get destination account: %w", err)
        }
        
        // 4. Deduct from source
        if err := tx.Model(&fromAccount).
            Update("balance", gorm.Expr("balance - ?", amount)).Error; err != nil {
            return err
        }
        
        // 5. Add to destination
        if err := tx.Model(&toAccount).
            Update("balance", gorm.Expr("balance + ?", amount)).Error; err != nil {
            return err
        }
        
        // 6. Create transfer record
        transfer := Transfer{
            ID:     uuid.New().String(),
            FromID: fromID,
            ToID:   toID,
            Amount: amount,
        }
        return tx.Create(&transfer).Error
    })
}
```

### Order Creation with Inventory

```go
func (s *OrderService) CreateOrder(ctx context.Context, req *CreateOrderRequest) (*Order, error) {
    var order Order
    
    err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
        // 1. Lock and check inventory
        for _, item := range req.Items {
            var product Product
            if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
                First(&product, "id = ?", item.ProductID).Error; err != nil {
                return fmt.Errorf("get product %s: %w", item.ProductID, err)
            }
            
            if product.Stock < item.Quantity {
                return fmt.Errorf("insufficient stock for %s", item.ProductID)
            }
        }
        
        // 2. Create order
        order = Order{
            ID:     uuid.New().String(),
            UserID: req.UserID,
            Status: "pending",
            Total:  req.Total,
        }
        if err := tx.Create(&order).Error; err != nil {
            return err
        }
        
        // 3. Create items and deduct inventory
        for _, item := range req.Items {
            orderItem := OrderItem{
                ID:        uuid.New().String(),
                OrderID:   order.ID,
                ProductID: item.ProductID,
                Quantity:  item.Quantity,
                Price:     item.Price,
            }
            if err := tx.Create(&orderItem).Error; err != nil {
                return err
            }
            
            if err := tx.Model(&Product{}).
                Where("id = ?", item.ProductID).
                Update("stock", gorm.Expr("stock - ?", item.Quantity)).Error; err != nil {
                return err
            }
        }
        
        return nil
    })
    
    if err != nil {
        return nil, err
    }
    return &order, nil
}
```

### Savepoint (Nested Transaction)

```go
err := db.Transaction(func(tx *gorm.DB) error {
    tx.Create(&user1)
    
    // Nested = Savepoint
    tx.Transaction(func(tx2 *gorm.DB) error {
        tx2.Create(&user2)
        return errors.New("rollback user2 only")
    })
    
    tx.Create(&user3) // Still executes
    return nil // Commit user1 and user3
})
```

## Preload (Avoid N+1)

### Basic Preload

```go
// ❌ N+1 Problem
var users []User
db.Find(&users)
for _, user := range users {
    db.Where("user_id = ?", user.ID).Find(&user.Orders) // N queries!
}

// ✅ Preload (2 queries)
var users []User
db.Preload("Orders").Find(&users)
```

### Nested Preload

```go
// Preload orders and items
var users []User
db.Preload("Orders.Items").Find(&users)

// Multiple preloads
db.Preload("Orders").Preload("Profile").Find(&users)
```

### Conditional Preload

```go
// With conditions
db.Preload("Orders", "status = ?", "completed").Find(&users)

// With custom query
db.Preload("Orders", func(db *gorm.DB) *gorm.DB {
    return db.Order("created_at DESC").Limit(5)
}).Find(&users)
```

### Joins

```go
// Filter by relation
var users []User
db.Joins("JOIN orders ON orders.user_id = users.id").
    Where("orders.total > ?", 1000).
    Distinct().
    Find(&users)

// Joins preload (single query with LEFT JOIN)
db.Joins("Profile").Find(&users)
```

## Pagination

### Offset-based

```go
func Paginate(page, pageSize int) func(db *gorm.DB) *gorm.DB {
    return func(db *gorm.DB) *gorm.DB {
        offset := (page - 1) * pageSize
        return db.Offset(offset).Limit(pageSize)
    }
}

var users []User
var total int64

db.Model(&User{}).Where("status = ?", "active").Count(&total)
db.Scopes(Paginate(page, pageSize)).
    Where("status = ?", "active").
    Order("created_at DESC").
    Find(&users)
```

### Cursor-based

```go
func (r *UserRepository) ListAfterCursor(ctx context.Context, cursor time.Time, limit int) ([]User, *time.Time, error) {
    var users []User
    
    err := r.db.WithContext(ctx).
        Where("created_at < ?", cursor).
        Order("created_at DESC").
        Limit(limit + 1).
        Find(&users).Error
    
    if err != nil {
        return nil, nil, err
    }
    
    var nextCursor *time.Time
    if len(users) > limit {
        nextCursor = &users[limit-1].CreatedAt
        users = users[:limit]
    }
    
    return users, nextCursor, nil
}
```

## Soft Delete

GORM 內建支援，只需加 `DeletedAt` 欄位。

```go
type User struct {
    ID        string         `gorm:"primaryKey"`
    Email     string
    DeletedAt gorm.DeletedAt `gorm:"index"` // 自動支援 soft delete
}

// Soft delete
db.Delete(&user) // UPDATE SET deleted_at = NOW()

// Find 自動排除已刪除
db.Find(&users) // WHERE deleted_at IS NULL

// 包含已刪除
db.Unscoped().Find(&users)

// 只查已刪除
db.Unscoped().Where("deleted_at IS NOT NULL").Find(&users)

// 恢復
db.Unscoped().Model(&user).Update("deleted_at", nil)

// Hard delete
db.Unscoped().Delete(&user)
```

## Optimistic Locking

```go
type Order struct {
    ID      string `gorm:"primaryKey"`
    Status  string
    Total   float64
    Version int `gorm:"default:1"`
}

func (r *OrderRepository) UpdateWithVersion(ctx context.Context, order *Order) error {
    result := r.db.WithContext(ctx).
        Model(order).
        Where("version = ?", order.Version).
        Updates(map[string]interface{}{
            "status":  order.Status,
            "total":   order.Total,
            "version": gorm.Expr("version + 1"),
        })
    
    if result.Error != nil {
        return result.Error
    }
    
    if result.RowsAffected == 0 {
        return ErrConcurrentUpdate
    }
    
    order.Version++
    return nil
}

// Service with retry
func (s *OrderService) UpdateOrderStatus(ctx context.Context, orderID, newStatus string) error {
    const maxRetries = 3
    
    for attempt := 0; attempt < maxRetries; attempt++ {
        var order Order
        if err := s.db.First(&order, "id = ?", orderID).Error; err != nil {
            return err
        }
        
        order.Status = newStatus
        
        if err := s.repo.UpdateWithVersion(ctx, &order); err == nil {
            return nil
        } else if errors.Is(err, ErrConcurrentUpdate) {
            continue
        } else {
            return err
        }
    }
    
    return ErrConcurrentUpdate
}
```

## Hooks

```go
func (u *User) BeforeCreate(tx *gorm.DB) error {
    if u.ID == "" {
        u.ID = uuid.New().String()
    }
    return nil
}

func (u *User) AfterCreate(tx *gorm.DB) error {
    // Audit log, send email, etc.
    return nil
}

func (u *User) BeforeUpdate(tx *gorm.DB) error {
    // Validation
    return nil
}

func (u *User) BeforeDelete(tx *gorm.DB) error {
    // Check dependencies
    return nil
}
```

## Scopes (Reusable Queries)

```go
func Active(db *gorm.DB) *gorm.DB {
    return db.Where("status = ?", "active")
}

func CreatedAfter(date time.Time) func(db *gorm.DB) *gorm.DB {
    return func(db *gorm.DB) *gorm.DB {
        return db.Where("created_at > ?", date)
    }
}

func OrderByLatest(db *gorm.DB) *gorm.DB {
    return db.Order("created_at DESC")
}

// Usage
db.Scopes(Active, OrderByLatest).Find(&users)
db.Scopes(Active, CreatedAfter(lastMonth)).Find(&users)
```

## Repository Pattern

```go
type UserRepository struct {
    db *gorm.DB
}

func NewUserRepository(db *gorm.DB) *UserRepository {
    return &UserRepository{db: db}
}

func (r *UserRepository) FindByID(ctx context.Context, id string) (*User, error) {
    var user User
    err := r.db.WithContext(ctx).First(&user, "id = ?", id).Error
    if errors.Is(err, gorm.ErrRecordNotFound) {
        return nil, nil
    }
    return &user, err
}

func (r *UserRepository) Create(ctx context.Context, user *User) error {
    return r.db.WithContext(ctx).Create(user).Error
}

func (r *UserRepository) Update(ctx context.Context, user *User) error {
    return r.db.WithContext(ctx).Save(user).Error
}

func (r *UserRepository) Delete(ctx context.Context, id string) error {
    return r.db.WithContext(ctx).Delete(&User{}, "id = ?", id).Error
}

func (r *UserRepository) List(ctx context.Context, page, pageSize int, status string) ([]User, int64, error) {
    var users []User
    var total int64
    
    query := r.db.WithContext(ctx).Model(&User{})
    if status != "" {
        query = query.Where("status = ?", status)
    }
    
    query.Count(&total)
    
    offset := (page - 1) * pageSize
    err := query.Offset(offset).Limit(pageSize).Order("created_at DESC").Find(&users).Error
    
    return users, total, err
}

// Transaction support
func (r *UserRepository) WithTx(tx *gorm.DB) *UserRepository {
    return &UserRepository{db: tx}
}
```

## Migration

### Auto Migration

```go
db.AutoMigrate(&User{}, &Order{}, &OrderItem{})
```

### Manual Migration (Recommended for Production)

```sql
-- migrations/000001_create_users.up.sql (PostgreSQL)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL,
    name VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uk_users_email UNIQUE (email)
);
CREATE INDEX idx_users_deleted_at ON users(deleted_at);

-- migrations/000001_create_users.up.sql (MySQL)
CREATE TABLE users (
    id CHAR(36) PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    name VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    deleted_at DATETIME(3),
    UNIQUE KEY uk_users_email (email),
    KEY idx_users_deleted_at (deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```
