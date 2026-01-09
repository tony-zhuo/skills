# Redis Patterns

Patterns for Redis 7+ with go-redis.

## Connection

```go
import "github.com/redis/go-redis/v9"

opt, _ := redis.ParseURL("redis://localhost:6379/0")
client := redis.NewClient(opt)

ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()

if err := client.Ping(ctx).Err(); err != nil {
    return nil, err
}
```

### Basic Operations

```go
// Set with TTL
err := client.Set(ctx, "key", "value", 30*time.Minute).Err()

// Get
val, err := client.Get(ctx, "key").Result()
if err == redis.Nil {
    // key not found
}

// Delete
err := client.Del(ctx, "key1", "key2").Err()

// Check exists
exists, err := client.Exists(ctx, "key").Result()
```

### Cache Pattern

```go
func GetUser(ctx context.Context, id string) (*User, error) {
    key := "user:" + id
    
    // Try cache
    data, err := client.Get(ctx, key).Bytes()
    if err == nil {
        var user User
        json.Unmarshal(data, &user)
        return &user, nil
    }
    if err != redis.Nil {
        return nil, err // real error
    }
    
    // Cache miss - load from DB
    user, err := loadFromDB(ctx, id)
    if err != nil {
        return nil, err
    }
    
    // Store in cache
    data, _ := json.Marshal(user)
    client.Set(ctx, key, data, 30*time.Minute)
    
    return user, nil
}
```

### Rate Limiting (Sliding Window)

```go
func Allow(ctx context.Context, key string, limit int, window time.Duration) (bool, error) {
    now := time.Now().UnixNano()
    windowStart := now - int64(window)
    
    pipe := client.Pipeline()
    pipe.ZRemRangeByScore(ctx, key, "-inf", fmt.Sprintf("%d", windowStart))
    countCmd := pipe.ZCard(ctx, key)
    pipe.ZAdd(ctx, key, redis.Z{Score: float64(now), Member: now})
    pipe.Expire(ctx, key, window)
    
    _, err := pipe.Exec(ctx)
    if err != nil {
        return false, err
    }
    
    return countCmd.Val() < int64(limit), nil
}
```

### Distributed Lock

```go
func Lock(ctx context.Context, key string, ttl time.Duration) (bool, error) {
    return client.SetNX(ctx, "lock:"+key, "1", ttl).Result()
}

func Unlock(ctx context.Context, key string) error {
    return client.Del(ctx, "lock:"+key).Err()
}

// Usage
acquired, _ := Lock(ctx, "order:123", 30*time.Second)
if !acquired {
    return ErrLocked
}
defer Unlock(ctx, "order:123")
// do work...
```

### Pub/Sub

```go
// Publisher
err := client.Publish(ctx, "channel", "message").Err()

// Subscriber
pubsub := client.Subscribe(ctx, "channel")
defer pubsub.Close()

ch := pubsub.Channel()
for msg := range ch {
    fmt.Println(msg.Channel, msg.Payload)
}
```

### Pipeline

```go
pipe := client.Pipeline()

pipe.Set(ctx, "key1", "value1", 0)
pipe.Set(ctx, "key2", "value2", 0)
pipe.Get(ctx, "key3")

cmds, err := pipe.Exec(ctx)
// cmds[2] contains Get result
```

### Lua Script (Atomic Operations)

Pipeline 不保證原子性，Lua script 保證原子性執行。

**基本用法**

```go
// Script 在 Redis server 上原子性執行
script := redis.NewScript(`
    local current = redis.call('GET', KEYS[1])
    if current == false then
        current = 0
    end
    local new = tonumber(current) + tonumber(ARGV[1])
    redis.call('SET', KEYS[1], new)
    return new
`)

// Run script
result, err := script.Run(ctx, client, []string{"counter"}, 10).Int()
// First run: loads and caches script (EVALSHA)
// Subsequent runs: uses cached script
```

**Check-and-Set (Atomic)**

```go
// Atomic: only set if current value matches expected
var casScript = redis.NewScript(`
    local current = redis.call('GET', KEYS[1])
    if current == ARGV[1] then
        redis.call('SET', KEYS[1], ARGV[2])
        return 1
    end
    return 0
`)

func CompareAndSwap(ctx context.Context, client *redis.Client, key, expected, newValue string) (bool, error) {
    result, err := casScript.Run(ctx, client, []string{key}, expected, newValue).Int()
    if err != nil {
        return false, err
    }
    return result == 1, nil
}
```

**Increment with Limit (Atomic)**

```go
// Atomic increment that respects a maximum value
var incrWithLimitScript = redis.NewScript(`
    local current = tonumber(redis.call('GET', KEYS[1]) or '0')
    local increment = tonumber(ARGV[1])
    local limit = tonumber(ARGV[2])
    
    if current + increment > limit then
        return -1  -- Would exceed limit
    end
    
    local new = current + increment
    redis.call('SET', KEYS[1], new)
    return new
`)

func IncrementWithLimit(ctx context.Context, client *redis.Client, key string, incr, limit int) (int, error) {
    result, err := incrWithLimitScript.Run(ctx, client, []string{key}, incr, limit).Int()
    if err != nil {
        return 0, err
    }
    if result == -1 {
        return 0, ErrLimitExceeded
    }
    return result, nil
}
```

**Distributed Lock (Correct Implementation)**

```go
// SET NX is not enough - need atomic check owner before delete
var lockScript = redis.NewScript(`
    if redis.call('SET', KEYS[1], ARGV[1], 'NX', 'PX', ARGV[2]) then
        return 1
    end
    return 0
`)

var unlockScript = redis.NewScript(`
    if redis.call('GET', KEYS[1]) == ARGV[1] then
        return redis.call('DEL', KEYS[1])
    end
    return 0
`)

var extendScript = redis.NewScript(`
    if redis.call('GET', KEYS[1]) == ARGV[1] then
        return redis.call('PEXPIRE', KEYS[1], ARGV[2])
    end
    return 0
`)

type DistributedLock struct {
    client *redis.Client
    key    string
    value  string // Unique owner identifier
    ttl    time.Duration
}

func NewDistributedLock(client *redis.Client, key string, ttl time.Duration) *DistributedLock {
    return &DistributedLock{
        client: client,
        key:    "lock:" + key,
        value:  uuid.New().String(), // Unique per lock instance
        ttl:    ttl,
    }
}

func (l *DistributedLock) Lock(ctx context.Context) (bool, error) {
    result, err := lockScript.Run(ctx, l.client, []string{l.key}, l.value, l.ttl.Milliseconds()).Int()
    if err != nil {
        return false, err
    }
    return result == 1, nil
}

func (l *DistributedLock) Unlock(ctx context.Context) error {
    // Only delete if we own the lock (atomic check + delete)
    _, err := unlockScript.Run(ctx, l.client, []string{l.key}, l.value).Result()
    return err
}

func (l *DistributedLock) Extend(ctx context.Context, ttl time.Duration) (bool, error) {
    result, err := extendScript.Run(ctx, l.client, []string{l.key}, l.value, ttl.Milliseconds()).Int()
    if err != nil {
        return false, err
    }
    return result == 1, nil
}

// Usage
lock := NewDistributedLock(client, "order:123", 30*time.Second)

acquired, err := lock.Lock(ctx)
if err != nil || !acquired {
    return ErrLockNotAcquired
}
defer lock.Unlock(ctx)

// Do work...
```

**Rate Limiter with Lua (Sliding Window - Atomic)**

```go
var rateLimitScript = redis.NewScript(`
    local key = KEYS[1]
    local limit = tonumber(ARGV[1])
    local window = tonumber(ARGV[2])
    local now = tonumber(ARGV[3])
    
    -- Remove old entries
    redis.call('ZREMRANGEBYSCORE', key, '-inf', now - window)
    
    -- Count current entries
    local count = redis.call('ZCARD', key)
    
    if count < limit then
        -- Add new entry
        redis.call('ZADD', key, now, now .. '-' .. math.random())
        redis.call('PEXPIRE', key, window)
        return 1  -- Allowed
    end
    
    return 0  -- Denied
`)

func (r *RateLimiter) Allow(ctx context.Context, key string, limit int, window time.Duration) (bool, error) {
    now := time.Now().UnixMilli()
    result, err := rateLimitScript.Run(ctx, r.client, 
        []string{key}, 
        limit, 
        window.Milliseconds(), 
        now,
    ).Int()
    if err != nil {
        return false, err
    }
    return result == 1, nil
}
```

**Atomic Inventory Deduction**

```go
var deductInventoryScript = redis.NewScript(`
    local key = KEYS[1]
    local quantity = tonumber(ARGV[1])
    
    local stock = tonumber(redis.call('GET', key) or '0')
    
    if stock < quantity then
        return -1  -- Insufficient stock
    end
    
    local new_stock = stock - quantity
    redis.call('SET', key, new_stock)
    return new_stock
`)

func DeductInventory(ctx context.Context, client *redis.Client, productID string, quantity int) (int, error) {
    key := "inventory:" + productID
    result, err := deductInventoryScript.Run(ctx, client, []string{key}, quantity).Int()
    if err != nil {
        return 0, err
    }
    if result == -1 {
        return 0, ErrInsufficientStock
    }
    return result, nil
}
```

**Multi-Key Atomic Operation**

```go
// Transfer points between users atomically
var transferPointsScript = redis.NewScript(`
    local from_key = KEYS[1]
    local to_key = KEYS[2]
    local amount = tonumber(ARGV[1])
    
    local from_balance = tonumber(redis.call('GET', from_key) or '0')
    
    if from_balance < amount then
        return {err = 'insufficient_balance'}
    end
    
    redis.call('DECRBY', from_key, amount)
    redis.call('INCRBY', to_key, amount)
    
    local new_from = tonumber(redis.call('GET', from_key))
    local new_to = tonumber(redis.call('GET', to_key))
    
    return {new_from, new_to}
`)

func TransferPoints(ctx context.Context, client *redis.Client, fromUser, toUser string, amount int) error {
    fromKey := "points:" + fromUser
    toKey := "points:" + toUser
    
    result, err := transferPointsScript.Run(ctx, client, []string{fromKey, toKey}, amount).Result()
    if err != nil {
        return err
    }
    
    // Check for custom error
    if m, ok := result.(map[interface{}]interface{}); ok {
        if errMsg, exists := m["err"]; exists {
            return fmt.Errorf("%v", errMsg)
        }
    }
    
    return nil
}
```

**Script Caching**

```go
// Load script once at startup
func (r *Repository) InitScripts(ctx context.Context) error {
    // Pre-load scripts to get SHA
    scripts := []*redis.Script{
        casScript,
        lockScript,
        unlockScript,
        rateLimitScript,
    }
    
    for _, script := range scripts {
        // Load caches the script and returns SHA
        if err := script.Load(ctx, r.client).Err(); err != nil {
            return fmt.Errorf("load script: %w", err)
        }
    }
    
    return nil
}
```

---

