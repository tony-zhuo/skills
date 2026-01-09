# Effective Go

Official Go idioms from [go.dev/doc/effective_go](https://go.dev/doc/effective_go).

## Formatting

Use `gofmt` (or `go fmt`). Don't fight it.

```bash
gofmt -w .           # Format all files
go fmt ./...         # Format package
```

- **Indentation**: Tabs, not spaces
- **Line length**: No limit, wrap if too long
- **Parentheses**: Fewer than C/Java (`if x > 0` not `if (x > 0)`)

---

## Naming

### Package Names

```go
// ✅ Good: short, lowercase, single word
package bufio
package http
package json

// ❌ Bad
package bufIO        // no mixedCaps
package string_util  // no underscores
package stringUtil   // no mixedCaps
```

Avoid stuttering:

```go
// ✅ Good
bufio.Reader    // not bufio.BufReader
ring.New()      // not ring.NewRing()
once.Do()       // not once.DoOrWaitUntilDone()

// ❌ Bad
http.HTTPServer // stutters
```

### Getters/Setters

```go
// ✅ Good: no "Get" prefix for getters
func (u *User) Name() string     // getter
func (u *User) SetName(n string) // setter

// ❌ Bad
func (u *User) GetName() string  // don't use Get prefix
```

### Interface Names

One-method interfaces: method name + `-er` suffix

```go
type Reader interface {
    Read(p []byte) (n int, err error)
}

type Writer interface {
    Write(p []byte) (n int, err error)
}

type Stringer interface {
    String() string
}

type Closer interface {
    Close() error
}
```

### MixedCaps

Always use `MixedCaps` or `mixedCaps`, never underscores.

```go
// ✅ Good
var userID string
var maxRetryCount int
type HTTPClient struct{}

// ❌ Bad
var user_id string
var max_retry_count int
type HTTP_Client struct{}
```

### Exported vs Unexported

```go
// Exported (public) - starts with uppercase
type User struct{}
func NewUser() *User

// Unexported (private) - starts with lowercase
type user struct{}
func newUser() *user
```

---

## Control Structures

### If

```go
// Initialization statement
if err := file.Chmod(0644); err != nil {
    log.Print(err)
    return err
}

// Avoid unnecessary else
f, err := os.Open(name)
if err != nil {
    return err
}
// continue with f...
```

### For

```go
// C-style
for i := 0; i < 10; i++ {}

// While-style
for condition {}

// Infinite
for {}

// Range
for key, value := range m {}
for key := range m {}           // key only
for _, value := range m {}      // value only

// Parallel assignment
for i, j := 0, len(a)-1; i < j; i, j = i+1, j-1 {
    a[i], a[j] = a[j], a[i]
}
```

### Switch

```go
// No automatic fallthrough (unlike C)
switch c {
case ' ', '\t', '\n':  // comma-separated
    return true
}

// Expression-less (like if-else chain)
switch {
case x < 0:
    return -1
case x > 0:
    return 1
default:
    return 0
}

// Break out of loop from switch
Loop:
    for {
        switch {
        case done:
            break Loop  // breaks the for loop
        }
    }
```

### Type Switch

```go
switch v := value.(type) {
case string:
    fmt.Printf("string: %s\n", v)
case int:
    fmt.Printf("int: %d\n", v)
case bool:
    fmt.Printf("bool: %t\n", v)
default:
    fmt.Printf("unknown type: %T\n", v)
}
```

---

## Functions

### Multiple Return Values

```go
func nextInt(b []byte, i int) (int, int) {
    // ...
    return x, i
}

// Common pattern: value + error
func Open(name string) (*File, error) {
    // ...
}
```

### Named Return Values

```go
// Names serve as documentation
func ReadFull(r Reader, buf []byte) (n int, err error) {
    for len(buf) > 0 && err == nil {
        var nr int
        nr, err = r.Read(buf)
        n += nr
        buf = buf[nr:]
    }
    return  // naked return uses named values
}
```

### Defer

```go
func Contents(filename string) (string, error) {
    f, err := os.Open(filename)
    if err != nil {
        return "", err
    }
    defer f.Close()  // runs when function returns
    
    // ... use f ...
    return string(result), nil
}
```

Defer rules:
- Executed in LIFO order (last defer runs first)
- Arguments evaluated when defer executes, not when function runs
- Deferred function can modify named return values

```go
// Trace example
func trace(s string) string {
    fmt.Println("entering:", s)
    return s
}

func un(s string) {
    fmt.Println("leaving:", s)
}

func a() {
    defer un(trace("a"))  // trace runs now, un runs on return
    fmt.Println("in a")
}
```

---

## Data

### new vs make

```go
// new(T) - allocates zeroed memory, returns *T
p := new(SyncedBuffer)  // type *SyncedBuffer, zeroed

// make(T) - initializes slices, maps, channels, returns T
s := make([]int, 10)    // type []int, length 10
m := make(map[string]int)
c := make(chan int, 10) // buffered channel
```

| | new | make |
|---|-----|------|
| Returns | `*T` (pointer) | `T` (value) |
| Memory | Zeroed | Initialized |
| Types | Any | Slice, Map, Channel only |

### Composite Literals

```go
// Struct
f := &File{fd: fd, name: name}

// Array
a := [...]string{0: "no error", 1: "Eio", 2: "invalid"}

// Slice
s := []string{"a", "b", "c"}

// Map
m := map[string]int{"one": 1, "two": 2}
```

### Slices

```go
// Slices reference arrays
s := make([]int, 5, 10)  // len=5, cap=10

// Slicing
s2 := s[2:4]  // shares underlying array

// Append
s = append(s, 1, 2, 3)

// Append slice to slice
s = append(s, other...)

// Copy
copy(dst, src)
```

### Maps

```go
m := make(map[string]int)

// Set
m["key"] = 1

// Get (returns zero value if missing)
v := m["key"]

// Check existence
v, ok := m["key"]
if !ok {
    // key not present
}

// Delete
delete(m, "key")
```

### Printing

```go
fmt.Printf("%v\n", value)    // default format
fmt.Printf("%+v\n", struct)  // with field names
fmt.Printf("%#v\n", value)   // Go syntax
fmt.Printf("%T\n", value)    // type
fmt.Printf("%q\n", str)      // quoted string
```

Custom format:

```go
func (t *T) String() string {
    return fmt.Sprintf("%d/%g/%q", t.a, t.b, t.c)
}
```

---

## Initialization

### Constants with iota

```go
type ByteSize float64

const (
    _           = iota  // ignore first
    KB ByteSize = 1 << (10 * iota)
    MB
    GB
    TB
    PB
)
```

### Variables

```go
var (
    home   = os.Getenv("HOME")
    user   = os.Getenv("USER")
    gopath = os.Getenv("GOPATH")
)
```

### init Function

```go
func init() {
    if user == "" {
        log.Fatal("$USER not set")
    }
    if home == "" {
        home = "/home/" + user
    }
}
```

- Called after all variable declarations
- Each file can have multiple init functions
- Can't be called explicitly

---

## Methods

### Pointer vs Value Receivers

```go
// Value receiver - doesn't modify
func (s Sequence) Len() int {
    return len(s)
}

// Pointer receiver - can modify
func (s *Sequence) Append(item int) {
    *s = append(*s, item)
}
```

Rules:
- **Value methods**: can be called on pointers and values
- **Pointer methods**: can only be called on pointers
- If any method needs pointer receiver, all should use pointer receiver

```go
// io.Writer requires pointer receiver
func (p *ByteSlice) Write(data []byte) (n int, err error) {
    *p = append(*p, data...)
    return len(data), nil
}

var b ByteSlice
fmt.Fprintf(&b, "Hello")  // &b satisfies io.Writer
```

---

## Interfaces

### Interface Design

```go
// Small interfaces are better
type Reader interface {
    Read(p []byte) (n int, err error)
}

type Writer interface {
    Write(p []byte) (n int, err error)
}

// Compose interfaces
type ReadWriter interface {
    Reader
    Writer
}
```

### Type Assertions

```go
// Single value (panics if wrong type)
str := value.(string)

// Comma-ok idiom (safe)
str, ok := value.(string)
if !ok {
    // value is not a string
}
```

### Return Interfaces

```go
// Return interface, not concrete type
func NewReader(data []byte) io.Reader {
    return bytes.NewReader(data)
}
```

### Interface Check at Compile Time

```go
// Verify *RawMessage implements json.Marshaler
var _ json.Marshaler = (*RawMessage)(nil)
```

---

## Embedding

### Struct Embedding

```go
type ReadWriter struct {
    *Reader  // embedded
    *Writer  // embedded
}

// Methods of Reader and Writer are promoted
rw := &ReadWriter{reader, writer}
rw.Read(buf)   // calls reader.Read
rw.Write(buf)  // calls writer.Write
```

```go
type Job struct {
    Command string
    *log.Logger  // embedded
}

// Can use Logger methods directly
job.Println("starting...")

// Access embedded field by type name
job.Logger.SetPrefix("Job: ")
```

### Interface Embedding

```go
type ReadWriter interface {
    Reader  // embedded interface
    Writer  // embedded interface
}
```

---

## Concurrency

### Share by Communicating

> Do not communicate by sharing memory; instead, share memory by communicating.

### Goroutines

```go
go func() {
    // runs concurrently
}()

go list.Sort()  // don't wait
```

### Channels

```go
// Unbuffered (synchronous)
c := make(chan int)

// Buffered
c := make(chan int, 100)

// Send
c <- value

// Receive
value := <-c

// Close
close(c)

// Range over channel
for v := range c {
    // ...
}
```

### Channel Patterns

```go
// Signal completion
done := make(chan bool)
go func() {
    doWork()
    done <- true
}()
<-done  // wait

// Semaphore (limit concurrency)
var sem = make(chan int, MaxOutstanding)

func handle(r *Request) {
    sem <- 1       // acquire
    process(r)
    <-sem          // release
}

// Worker pool
func worker(jobs <-chan Job, results chan<- Result) {
    for job := range jobs {
        results <- process(job)
    }
}
```

### Select

```go
select {
case v := <-ch1:
    // received from ch1
case ch2 <- x:
    // sent x to ch2
case <-time.After(timeout):
    // timeout
default:
    // non-blocking
}
```

### Leaky Buffer (Free List)

```go
var freeList = make(chan *Buffer, 100)

func getBuffer() *Buffer {
    select {
    case b := <-freeList:
        return b
    default:
        return new(Buffer)
    }
}

func putBuffer(b *Buffer) {
    select {
    case freeList <- b:
        // returned to pool
    default:
        // pool full, drop it (GC will reclaim)
    }
}
```

---

## Errors

### Error Interface

```go
type error interface {
    Error() string
}

// Custom error
type PathError struct {
    Op   string
    Path string
    Err  error
}

func (e *PathError) Error() string {
    return e.Op + " " + e.Path + ": " + e.Err.Error()
}
```

### Error Handling

```go
f, err := os.Open(name)
if err != nil {
    return err
}
defer f.Close()

// Check specific error type
if e, ok := err.(*os.PathError); ok && e.Err == syscall.ENOSPC {
    // handle disk full
}
```

### Panic

Only for unrecoverable errors:

```go
func init() {
    if user == "" {
        panic("no value for $USER")
    }
}
```

### Recover

```go
func safelyDo(work *Work) {
    defer func() {
        if err := recover(); err != nil {
            log.Println("work failed:", err)
        }
    }()
    do(work)  // may panic
}
```

```go
// Convert panic to error
func Compile(str string) (regexp *Regexp, err error) {
    defer func() {
        if e := recover(); e != nil {
            regexp = nil
            err = e.(Error)  // re-panic if not our error type
        }
    }()
    return doParse(str), nil
}
```

---

## Blank Identifier

```go
// Ignore value
_, err := os.Stat(path)

// Ignore index
for _, v := range slice {}

// Import for side effects
import _ "net/http/pprof"

// Interface check
var _ json.Marshaler = (*MyType)(nil)

// Silence unused import during development
var _ = fmt.Printf
```

---

## Quick Reference

| Topic | Idiom |
|-------|-------|
| Formatting | Use `gofmt` |
| Package names | Short, lowercase, no underscores |
| Getters | `Name()` not `GetName()` |
| Interfaces | Small, -er suffix |
| Errors | Return, don't panic |
| Receivers | Pointer if modifying |
| Concurrency | Channels over mutexes |
| Initialization | Zero values should be useful |
