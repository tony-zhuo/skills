# Design Patterns

> 註：本檔案著重於常用模式的「idiomatic Go」範例，完整 GoF 模式實作可參考外部倉庫 `https://github.com/tony-zhuo/golang-design-pattern`。  
> 目錄對應：`00_simple_factory`、`01_facade`、`02_adapter`、`03_singleton`、`04_factory_method`、`05_abstract_factory`、`06_builder`、`07_prototype`、`08_mediator`、`09_proxy`、`10_observer`、`11_command`、`12_iterator`、`13_composite`、`14_template_method`、`15_strategy`、`16_state`、`17_memento`、`18_flyweight`、`19_interpreter`、`20_decorator`、`21_chain_of_responsibility`、`22_bridge`、`23_visitor`。

## Creational Patterns

### Simple Factory

```go
type ShapeType string

const (
    ShapeCircle ShapeType = "circle"
    ShapeRect   ShapeType = "rect"
)

type Shape interface {
    Area() float64
}

type Circle struct{ R float64 }
func (c *Circle) Area() float64 { return math.Pi * c.R * c.R }

type Rect struct{ W, H float64 }
func (r *Rect) Area() float64 { return r.W * r.H }

// Simple factory 封裝建立細節
func NewShape(t ShapeType, args ...float64) (Shape, error) {
    switch t {
    case ShapeCircle:
        if len(args) != 1 {
            return nil, errors.New("circle needs radius")
        }
        return &Circle{R: args[0]}, nil
    case ShapeRect:
        if len(args) != 2 {
            return nil, errors.New("rect needs width and height")
        }
        return &Rect{W: args[0], H: args[1]}, nil
    default:
        return nil, fmt.Errorf("unknown shape: %s", t)
    }
}
```

### Factory

```go
type NotifierType string

const (
    NotifierEmail NotifierType = "email"
    NotifierSMS   NotifierType = "sms"
    NotifierSlack NotifierType = "slack"
)

type Notifier interface {
    Send(ctx context.Context, to, message string) error
}

func NewNotifier(t NotifierType, cfg Config) (Notifier, error) {
    switch t {
    case NotifierEmail:
        return &EmailNotifier{cfg: cfg}, nil
    case NotifierSMS:
        return &SMSNotifier{cfg: cfg}, nil
    case NotifierSlack:
        return &SlackNotifier{cfg: cfg}, nil
    default:
        return nil, fmt.Errorf("unknown notifier type: %s", t)
    }
}
```

### Factory Method

```go
type StorageFactory interface {
    CreateStorage() Storage
}

type Storage interface {
    Save(ctx context.Context, key string, data []byte) error
    Load(ctx context.Context, key string) ([]byte, error)
}

type S3Factory struct {
    bucket string
    client *s3.Client
}

func (f *S3Factory) CreateStorage() Storage {
    return &S3Storage{bucket: f.bucket, client: f.client}
}

type LocalFactory struct {
    basePath string
}

func (f *LocalFactory) CreateStorage() Storage {
    return &LocalStorage{basePath: f.basePath}
}

// Usage - depends on interface
func ProcessFiles(factory StorageFactory) {
    storage := factory.CreateStorage()
    storage.Save(ctx, "key", data)
}
```

### Abstract Factory

```go
type UIFactory interface {
    CreateButton() Button
    CreateInput() Input
    CreateModal() Modal
}

// Material UI Factory
type MaterialUIFactory struct{}

func (f *MaterialUIFactory) CreateButton() Button { return &MaterialButton{} }
func (f *MaterialUIFactory) CreateInput() Input   { return &MaterialInput{} }
func (f *MaterialUIFactory) CreateModal() Modal   { return &MaterialModal{} }

// Bootstrap Factory
type BootstrapFactory struct{}

func (f *BootstrapFactory) CreateButton() Button { return &BootstrapButton{} }
func (f *BootstrapFactory) CreateInput() Input   { return &BootstrapInput{} }
func (f *BootstrapFactory) CreateModal() Modal   { return &BootstrapModal{} }

// Usage
func RenderForm(factory UIFactory) string {
    button := factory.CreateButton()
    input := factory.CreateInput()
    return input.Render() + button.Render()
}
```

### Builder

```go
type HTTPClient struct {
    baseURL    string
    timeout    time.Duration
    retries    int
    headers    map[string]string
}

type HTTPClientBuilder struct {
    client HTTPClient
}

func NewHTTPClientBuilder() *HTTPClientBuilder {
    return &HTTPClientBuilder{
        client: HTTPClient{
            timeout: 30 * time.Second,
            retries: 3,
            headers: make(map[string]string),
        },
    }
}

func (b *HTTPClientBuilder) BaseURL(url string) *HTTPClientBuilder {
    b.client.baseURL = url
    return b
}

func (b *HTTPClientBuilder) Timeout(d time.Duration) *HTTPClientBuilder {
    b.client.timeout = d
    return b
}

func (b *HTTPClientBuilder) Retries(n int) *HTTPClientBuilder {
    b.client.retries = n
    return b
}

func (b *HTTPClientBuilder) Header(key, value string) *HTTPClientBuilder {
    b.client.headers[key] = value
    return b
}

func (b *HTTPClientBuilder) Build() (*HTTPClient, error) {
    if b.client.baseURL == "" {
        return nil, errors.New("baseURL is required")
    }
    return &b.client, nil
}

// Usage
client, _ := NewHTTPClientBuilder().
    BaseURL("https://api.example.com").
    Timeout(10 * time.Second).
    Header("Authorization", "Bearer token").
    Build()
```

### Options Pattern (Functional Options)

```go
type Server struct {
    host      string
    port      int
    timeout   time.Duration
    maxConn   int
    tlsConfig *tls.Config
}

type Option func(*Server)

func WithHost(host string) Option {
    return func(s *Server) { s.host = host }
}

func WithPort(port int) Option {
    return func(s *Server) { s.port = port }
}

func WithTimeout(d time.Duration) Option {
    return func(s *Server) { s.timeout = d }
}

func WithTLS(cfg *tls.Config) Option {
    return func(s *Server) { s.tlsConfig = cfg }
}

func NewServer(opts ...Option) *Server {
    s := &Server{
        host:    "localhost",
        port:    8080,
        timeout: 30 * time.Second,
        maxConn: 100,
    }
    for _, opt := range opts {
        opt(s)
    }
    return s
}

// Usage
server := NewServer(
    WithHost("0.0.0.0"),
    WithPort(9000),
    WithTimeout(60*time.Second),
)
```

### Singleton

```go
type Database struct {
    conn *sql.DB
}

var (
    dbInstance *Database
    dbOnce     sync.Once
)

func GetDatabase() *Database {
    dbOnce.Do(func() {
        conn, _ := sql.Open("postgres", os.Getenv("DATABASE_URL"))
        dbInstance = &Database{conn: conn}
    })
    return dbInstance
}
```

### Prototype

```go
type Prototype interface {
    Clone() Prototype
}

type Document struct {
    Title    string
    Content  string
    Metadata map[string]string
}

func (d *Document) Clone() Prototype {
    metadata := make(map[string]string)
    for k, v := range d.Metadata {
        metadata[k] = v
    }
    return &Document{
        Title:    d.Title,
        Content:  d.Content,
        Metadata: metadata,
    }
}

// Usage
template := &Document{Title: "Template", Metadata: map[string]string{"v": "1"}}
doc1 := template.Clone().(*Document)
doc1.Title = "Doc 1"
```

---

## Structural Patterns

### Adapter

```go
// Target interface
type PaymentProcessor interface {
    ProcessPayment(ctx context.Context, amount float64, currency string) (string, error)
}

// Adaptee (third-party SDK)
type StripeSDK struct{}

func (s *StripeSDK) CreateCharge(amountCents int64, curr, desc string) (*StripeCharge, error) {
    return &StripeCharge{ID: "ch_xxx"}, nil
}

// Adapter
type StripeAdapter struct {
    sdk *StripeSDK
}

func (a *StripeAdapter) ProcessPayment(ctx context.Context, amount float64, currency string) (string, error) {
    amountCents := int64(amount * 100)
    charge, err := a.sdk.CreateCharge(amountCents, currency, "Payment")
    if err != nil {
        return "", err
    }
    return charge.ID, nil
}

// Usage - depends on interface
func ProcessOrder(processor PaymentProcessor, amount float64) error {
    txID, err := processor.ProcessPayment(ctx, amount, "USD")
    // ...
}
```

### Decorator

```go
type Repository interface {
    Get(ctx context.Context, id string) (*Entity, error)
    Save(ctx context.Context, entity *Entity) error
}

// Base
type PostgresRepository struct{ db *sql.DB }

func (r *PostgresRepository) Get(ctx context.Context, id string) (*Entity, error) { ... }
func (r *PostgresRepository) Save(ctx context.Context, entity *Entity) error { ... }

// Caching decorator
type CachingRepository struct {
    repo  Repository
    cache *redis.Client
    ttl   time.Duration
}

func (r *CachingRepository) Get(ctx context.Context, id string) (*Entity, error) {
    key := "entity:" + id
    if data, err := r.cache.Get(ctx, key).Bytes(); err == nil {
        var entity Entity
        json.Unmarshal(data, &entity)
        return &entity, nil
    }
    
    entity, err := r.repo.Get(ctx, id)
    if err == nil {
        data, _ := json.Marshal(entity)
        r.cache.Set(ctx, key, data, r.ttl)
    }
    return entity, err
}

// Logging decorator
type LoggingRepository struct {
    repo   Repository
    logger *slog.Logger
}

func (r *LoggingRepository) Get(ctx context.Context, id string) (*Entity, error) {
    start := time.Now()
    entity, err := r.repo.Get(ctx, id)
    r.logger.Info("repo.Get", slog.Duration("duration", time.Since(start)))
    return entity, err
}

// Stack decorators
baseRepo := &PostgresRepository{db: db}
cachedRepo := &CachingRepository{repo: baseRepo, cache: redis, ttl: 5*time.Minute}
loggedRepo := &LoggingRepository{repo: cachedRepo, logger: logger}
```

### Facade

```go
type OrderFacade struct {
    inventory    *InventoryService
    payment      *PaymentService
    shipping     *ShippingService
    notification *NotificationService
}

func (f *OrderFacade) PlaceOrder(ctx context.Context, order *Order) error {
    // 1. Check & reserve inventory
    if err := f.inventory.Reserve(order.ProductID, order.Quantity); err != nil {
        return err
    }
    
    // 2. Process payment
    if err := f.payment.Charge(order.Total); err != nil {
        f.inventory.Release(order.ProductID, order.Quantity)
        return err
    }
    
    // 3. Create shipment
    trackingID, _ := f.shipping.CreateShipment(order.ID, order.Address)
    
    // 4. Send notification
    f.notification.SendEmail(order.CustomerEmail, "Order Confirmed", trackingID)
    
    return nil
}
```

### Proxy

```go
// Lazy loading proxy
type ImageProxy struct {
    filename string
    image    *HighResolutionImage
}

func (p *ImageProxy) Display() error {
    if p.image == nil {
        p.image = LoadHighResImage(p.filename) // Expensive
    }
    return p.image.Display()
}

// Protection proxy
type AccessProxy struct {
    resource ProtectedResource
    userRole string
}

func (p *AccessProxy) Access() (string, error) {
    if p.userRole != "admin" {
        return "", errors.New("access denied")
    }
    return p.resource.Access()
}
```

### Composite

```go
type FileSystemNode interface {
    GetName() string
    GetSize() int64
}

// Leaf
type File struct {
    name string
    size int64
}

func (f *File) GetName() string { return f.name }
func (f *File) GetSize() int64  { return f.size }

// Composite
type Directory struct {
    name     string
    children []FileSystemNode
}

func (d *Directory) GetName() string { return d.name }
func (d *Directory) GetSize() int64 {
    var total int64
    for _, child := range d.children {
        total += child.GetSize()
    }
    return total
}

func (d *Directory) Add(node FileSystemNode) {
    d.children = append(d.children, node)
}
```

### Bridge

```go
// Implementor
type MessageSender interface {
    Send(to, content string) error
}

type EmailSender struct{}
func (s *EmailSender) Send(to, content string) error {
    fmt.Println("email to", to, ":", content)
    return nil
}

type SMSSender struct{}
func (s *SMSSender) Send(to, content string) error {
    fmt.Println("sms to", to, ":", content)
    return nil
}

// Abstraction
type Notification struct {
    sender MessageSender
}

func NewNotification(sender MessageSender) *Notification {
    return &Notification{sender: sender}
}

func (n *Notification) Send(to, content string) error {
    return n.sender.Send(to, content)
}

// Usage: runtime 決定組合
// n := NewNotification(&EmailSender{})
// n.Send("tony@example.com", "hello")
```

### Flyweight

```go
// Intrinsic state
type Glyph struct {
    char rune
    font string
}

// Flyweight factory：共用相同組合
type GlyphFactory struct {
    cache map[string]*Glyph
}

func NewGlyphFactory() *GlyphFactory {
    return &GlyphFactory{cache: make(map[string]*Glyph)}
}

func (f *GlyphFactory) GetGlyph(char rune, font string) *Glyph {
    key := fmt.Sprintf("%c:%s", char, font)
    if g, ok := f.cache[key]; ok {
        return g
    }
    g := &Glyph{char: char, font: font}
    f.cache[key] = g
    return g
}

// Extrinsic state 由外部傳入
type GlyphPosition struct {
    Glyph *Glyph
    X, Y  int
}
```

---

## Behavioral Patterns

### Strategy

```go
type PaymentStrategy interface {
    Pay(amount float64) error
}

type CreditCardPayment struct{ cardNumber string }
func (c *CreditCardPayment) Pay(amount float64) error {
    fmt.Printf("Paid %.2f via Credit Card\n", amount)
    return nil
}

type PayPalPayment struct{ email string }
func (p *PayPalPayment) Pay(amount float64) error {
    fmt.Printf("Paid %.2f via PayPal\n", amount)
    return nil
}

type CryptoPayment struct{ wallet string }
func (c *CryptoPayment) Pay(amount float64) error {
    fmt.Printf("Paid %.2f via Crypto\n", amount)
    return nil
}

// Context
type ShoppingCart struct {
    items    []Item
    strategy PaymentStrategy
}

func (s *ShoppingCart) SetPaymentStrategy(strategy PaymentStrategy) {
    s.strategy = strategy
}

func (s *ShoppingCart) Checkout() error {
    return s.strategy.Pay(s.calculateTotal())
}

// Usage
cart := &ShoppingCart{items: items}
cart.SetPaymentStrategy(&CreditCardPayment{cardNumber: "1234..."})
cart.Checkout()
```

### Observer (Event Bus)

```go
type Observer interface {
    Update(event Event)
}

type Event struct {
    Type    string
    Payload interface{}
}

type EventBus struct {
    mu        sync.RWMutex
    observers map[string][]Observer
}

func NewEventBus() *EventBus {
    return &EventBus{observers: make(map[string][]Observer)}
}

func (b *EventBus) Subscribe(eventType string, observer Observer) {
    b.mu.Lock()
    defer b.mu.Unlock()
    b.observers[eventType] = append(b.observers[eventType], observer)
}

func (b *EventBus) Publish(event Event) {
    b.mu.RLock()
    defer b.mu.RUnlock()
    for _, obs := range b.observers[event.Type] {
        go obs.Update(event)
    }
}

// Observers
type EmailNotifier struct{ service *EmailService }
func (n *EmailNotifier) Update(event Event) {
    if event.Type == "order.created" {
        order := event.Payload.(*Order)
        n.service.Send(order.Email, "Order Confirmed", "...")
    }
}

type AnalyticsTracker struct{ analytics *Analytics }
func (t *AnalyticsTracker) Update(event Event) {
    t.analytics.Track(event.Type, event.Payload)
}

// Usage
bus := NewEventBus()
bus.Subscribe("order.created", &EmailNotifier{service})
bus.Subscribe("order.created", &AnalyticsTracker{analytics})
bus.Publish(Event{Type: "order.created", Payload: order})
```

### Command

```go
type Command interface {
    Execute() error
    Undo() error
}

type InsertCommand struct {
    editor   *TextEditor
    text     string
    position int
}

func (c *InsertCommand) Execute() error {
    c.editor.Insert(c.text, c.position)
    return nil
}

func (c *InsertCommand) Undo() error {
    c.editor.Delete(c.position, len(c.text))
    return nil
}

// Command Manager with history
type CommandManager struct {
    history []Command
    index   int
}

func (m *CommandManager) Execute(cmd Command) error {
    if err := cmd.Execute(); err != nil {
        return err
    }
    m.history = m.history[:m.index+1]
    m.history = append(m.history, cmd)
    m.index++
    return nil
}

func (m *CommandManager) Undo() error {
    if m.index < 0 {
        return errors.New("nothing to undo")
    }
    m.history[m.index].Undo()
    m.index--
    return nil
}

func (m *CommandManager) Redo() error {
    if m.index >= len(m.history)-1 {
        return errors.New("nothing to redo")
    }
    m.index++
    return m.history[m.index].Execute()
}
```

### Chain of Responsibility

```go
type Handler interface {
    SetNext(handler Handler) Handler
    Handle(request Request) error
}

type BaseHandler struct {
    next Handler
}

func (h *BaseHandler) SetNext(handler Handler) Handler {
    h.next = handler
    return handler
}

func (h *BaseHandler) Handle(request Request) error {
    if h.next != nil {
        return h.next.Handle(request)
    }
    return nil
}

// Concrete handlers
type AuthHandler struct {
    BaseHandler
    auth *AuthService
}

func (h *AuthHandler) Handle(request Request) error {
    if _, err := h.auth.ValidateToken(request.Token); err != nil {
        return errors.New("unauthorized")
    }
    return h.BaseHandler.Handle(request)
}

type RateLimitHandler struct {
    BaseHandler
    limiter *RateLimiter
}

func (h *RateLimitHandler) Handle(request Request) error {
    if !h.limiter.Allow(request.UserID) {
        return errors.New("rate limit exceeded")
    }
    return h.BaseHandler.Handle(request)
}

type ValidationHandler struct {
    BaseHandler
}

func (h *ValidationHandler) Handle(request Request) error {
    if err := validate(request.Body); err != nil {
        return err
    }
    return h.BaseHandler.Handle(request)
}

// Build chain
auth := &AuthHandler{auth: authService}
rateLimit := &RateLimitHandler{limiter: limiter}
validation := &ValidationHandler{}

auth.SetNext(rateLimit).SetNext(validation)
err := auth.Handle(request)
```

### State

```go
type OrderState interface {
    Confirm(o *Order) error
    Ship(o *Order) error
    Deliver(o *Order) error
    Cancel(o *Order) error
}

type Order struct {
    ID    string
    state OrderState
}

func NewOrder(id string) *Order {
    return &Order{ID: id, state: &PendingState{}}
}

func (o *Order) SetState(state OrderState) { o.state = state }
func (o *Order) Confirm() error            { return o.state.Confirm(o) }
func (o *Order) Ship() error               { return o.state.Ship(o) }
func (o *Order) Deliver() error            { return o.state.Deliver(o) }
func (o *Order) Cancel() error             { return o.state.Cancel(o) }

// States
type PendingState struct{}

func (s *PendingState) Confirm(o *Order) error {
    o.SetState(&ConfirmedState{})
    return nil
}
func (s *PendingState) Ship(o *Order) error    { return errors.New("cannot ship pending order") }
func (s *PendingState) Deliver(o *Order) error { return errors.New("cannot deliver pending order") }
func (s *PendingState) Cancel(o *Order) error {
    o.SetState(&CancelledState{})
    return nil
}

type ConfirmedState struct{}

func (s *ConfirmedState) Confirm(o *Order) error { return errors.New("already confirmed") }
func (s *ConfirmedState) Ship(o *Order) error {
    o.SetState(&ShippedState{})
    return nil
}
func (s *ConfirmedState) Deliver(o *Order) error { return errors.New("must ship first") }
func (s *ConfirmedState) Cancel(o *Order) error {
    o.SetState(&CancelledState{})
    return nil
}

type ShippedState struct{}

func (s *ShippedState) Confirm(o *Order) error { return errors.New("already shipped") }
func (s *ShippedState) Ship(o *Order) error    { return errors.New("already shipped") }
func (s *ShippedState) Deliver(o *Order) error {
    o.SetState(&DeliveredState{})
    return nil
}
func (s *ShippedState) Cancel(o *Order) error { return errors.New("cannot cancel shipped order") }

type DeliveredState struct{}
type CancelledState struct{}
// ... terminal states return errors for all transitions
```

### Template Method

```go
type DataExporter interface {
    FormatHeader() string
    FormatRow(data map[string]interface{}) string
    FormatFooter() string
}

type BaseExporter struct {
    Formatter DataExporter
}

func (e *BaseExporter) Export(data []map[string]interface{}) string {
    var result strings.Builder
    result.WriteString(e.Formatter.FormatHeader())
    for _, row := range data {
        result.WriteString(e.Formatter.FormatRow(row))
    }
    result.WriteString(e.Formatter.FormatFooter())
    return result.String()
}

// CSV
type CSVExporter struct{}

func (e *CSVExporter) FormatHeader() string { return "id,name,email\n" }
func (e *CSVExporter) FormatRow(data map[string]interface{}) string {
    return fmt.Sprintf("%v,%v,%v\n", data["id"], data["name"], data["email"])
}
func (e *CSVExporter) FormatFooter() string { return "" }

// JSON
type JSONExporter struct{}

func (e *JSONExporter) FormatHeader() string { return "[" }
func (e *JSONExporter) FormatRow(data map[string]interface{}) string {
    b, _ := json.Marshal(data)
    return string(b) + ","
}
func (e *JSONExporter) FormatFooter() string { return "]" }

// Usage
csvExporter := &BaseExporter{Formatter: &CSVExporter{}}
csvExporter.Export(data)
```

### Visitor

```go
type Visitor interface {
    VisitCircle(c *Circle)
    VisitRectangle(r *Rectangle)
}

type Shape interface {
    Accept(visitor Visitor)
}

type Circle struct{ Radius float64 }
func (c *Circle) Accept(v Visitor) { v.VisitCircle(c) }

type Rectangle struct{ Width, Height float64 }
func (r *Rectangle) Accept(v Visitor) { v.VisitRectangle(r) }

// Concrete visitor
type AreaCalculator struct {
    TotalArea float64
}

func (a *AreaCalculator) VisitCircle(c *Circle) {
    a.TotalArea += math.Pi * c.Radius * c.Radius
}

func (a *AreaCalculator) VisitRectangle(r *Rectangle) {
    a.TotalArea += r.Width * r.Height
}

// Usage
shapes := []Shape{&Circle{5}, &Rectangle{4, 6}}
calc := &AreaCalculator{}
for _, s := range shapes {
    s.Accept(calc)
}
fmt.Println(calc.TotalArea)
```

### Mediator

```go
// Mediator 介面
type ChatMediator interface {
    Broadcast(from, msg string)
}

// Colleague
type ChatUser struct {
    Name     string
    mediator ChatMediator
}

func (u *ChatUser) Send(msg string) {
    u.mediator.Broadcast(u.Name, msg)
}

func (u *ChatUser) Receive(from, msg string) {
    fmt.Printf("[%s] %s: %s\n", time.Now().Format(time.RFC3339), from, msg)
}

// Concrete mediator
type Room struct {
    mu    sync.RWMutex
    users map[string]*ChatUser
}

func NewRoom() *Room {
    return &Room{users: make(map[string]*ChatUser)}
}

func (r *Room) AddUser(u *ChatUser) {
    r.mu.Lock()
    defer r.mu.Unlock()
    u.mediator = r
    r.users[u.Name] = u
}

func (r *Room) Broadcast(from, msg string) {
    r.mu.RLock()
    defer r.mu.RUnlock()
    for name, u := range r.users {
        if name == from {
            continue
        }
        u.Receive(from, msg)
    }
}
```

### Iterator

```go
type Iterator[T any] interface {
    HasNext() bool
    Next() T
}

// Slice iterator
type SliceIterator[T any] struct {
    data []T
    idx  int
}

func NewSliceIterator[T any](data []T) *SliceIterator[T] {
    return &SliceIterator[T]{data: data}
}

func (it *SliceIterator[T]) HasNext() bool {
    return it.idx < len(it.data)
}

func (it *SliceIterator[T]) Next() T {
    v := it.data[it.idx]
    it.idx++
    return v
}

// Usage with generic constraint
// it := NewSliceIterator([]int{1, 2, 3})
// for it.HasNext() { fmt.Println(it.Next()) }
```

### Memento

```go
// Memento
type EditorState struct {
    Content string
    Cursor  int
}

// Originator
type Editor struct {
    content string
    cursor  int
}

func (e *Editor) Type(text string) {
    e.content = e.content[:e.cursor] + text + e.content[e.cursor:]
    e.cursor += len(text)
}

func (e *Editor) MoveCursor(pos int) {
    if pos >= 0 && pos <= len(e.content) {
        e.cursor = pos
    }
}

func (e *Editor) Save() EditorState {
    return EditorState{Content: e.content, Cursor: e.cursor}
}

func (e *Editor) Restore(s EditorState) {
    e.content = s.Content
    e.cursor = s.Cursor
}

// Caretaker
type History struct {
    stack []EditorState
}

func (h *History) Push(s EditorState) {
    h.stack = append(h.stack, s)
}

func (h *History) Pop() (EditorState, bool) {
    if len(h.stack) == 0 {
        return EditorState{}, false
    }
    last := h.stack[len(h.stack)-1]
    h.stack = h.stack[:len(h.stack)-1]
    return last, true
}
```

### Interpreter

```go
// 解析簡單表達式：number +/- number
type Expr interface {
    Eval() int
}

type Number struct{ Value int }
func (n *Number) Eval() int { return n.Value }

type Add struct{ Left, Right Expr }
func (a *Add) Eval() int { return a.Left.Eval() + a.Right.Eval() }

type Sub struct{ Left, Right Expr }
func (s *Sub) Eval() int { return s.Left.Eval() - s.Right.Eval() }

// 非完整 parser，只示意 interpreter 結構
func ParseExpr(tokens []string) Expr {
    // 例如 "1 + 2 - 3" -> ((1 + 2) - 3)
    if len(tokens) == 1 {
        v, _ := strconv.Atoi(tokens[0])
        return &Number{Value: v}
    }
    left := ParseExpr(tokens[:len(tokens)-2])
    rightVal, _ := strconv.Atoi(tokens[len(tokens)-1])
    right := &Number{Value: rightVal}

    op := tokens[len(tokens)-2]
    switch op {
    case "+":
        return &Add{Left: left, Right: right}
    case "-":
        return &Sub{Left: left, Right: right}
    default:
        return left
    }
}

// Usage
// expr := ParseExpr(strings.Split("1 + 2 - 3", " "))
// fmt.Println(expr.Eval()) // 0
```

---

## Go-Specific Patterns

### Circuit Breaker

```go
type State int

const (
    StateClosed State = iota
    StateOpen
    StateHalfOpen
)

type CircuitBreaker struct {
    mu              sync.RWMutex
    state           State
    failures        int
    successes       int
    lastFailureTime time.Time
    maxFailures     int
    timeout         time.Duration
    successThreshold int
}

func NewCircuitBreaker(maxFailures int, timeout time.Duration) *CircuitBreaker {
    return &CircuitBreaker{
        maxFailures:      maxFailures,
        timeout:          timeout,
        successThreshold: 3,
    }
}

func (cb *CircuitBreaker) Execute(fn func() error) error {
    if !cb.allowRequest() {
        return errors.New("circuit breaker is open")
    }
    
    err := fn()
    cb.recordResult(err)
    return err
}

func (cb *CircuitBreaker) allowRequest() bool {
    cb.mu.RLock()
    defer cb.mu.RUnlock()
    
    switch cb.state {
    case StateClosed:
        return true
    case StateOpen:
        if time.Since(cb.lastFailureTime) > cb.timeout {
            cb.mu.RUnlock()
            cb.mu.Lock()
            cb.state = StateHalfOpen
            cb.successes = 0
            cb.mu.Unlock()
            cb.mu.RLock()
            return true
        }
        return false
    case StateHalfOpen:
        return true
    }
    return false
}

func (cb *CircuitBreaker) recordResult(err error) {
    cb.mu.Lock()
    defer cb.mu.Unlock()
    
    if err != nil {
        cb.failures++
        cb.lastFailureTime = time.Now()
        if cb.state == StateHalfOpen || cb.failures >= cb.maxFailures {
            cb.state = StateOpen
        }
    } else {
        if cb.state == StateHalfOpen {
            cb.successes++
            if cb.successes >= cb.successThreshold {
                cb.state = StateClosed
                cb.failures = 0
            }
        } else {
            cb.failures = 0
        }
    }
}
```

### Retry with Backoff

```go
type BackoffStrategy interface {
    NextDelay(attempt int) time.Duration
}

type ExponentialBackoff struct {
    InitialDelay time.Duration
    MaxDelay     time.Duration
    Multiplier   float64
}

func (b *ExponentialBackoff) NextDelay(attempt int) time.Duration {
    delay := float64(b.InitialDelay) * math.Pow(b.Multiplier, float64(attempt))
    // Add jitter
    jitter := 0.5 + rand.Float64()
    delay *= jitter
    if delay > float64(b.MaxDelay) {
        delay = float64(b.MaxDelay)
    }
    return time.Duration(delay)
}

func Retry(ctx context.Context, maxAttempts int, backoff BackoffStrategy, fn func() error) error {
    var lastErr error
    
    for attempt := 0; attempt < maxAttempts; attempt++ {
        if err := fn(); err == nil {
            return nil
        } else {
            lastErr = err
        }
        
        if attempt == maxAttempts-1 {
            break
        }
        
        select {
        case <-ctx.Done():
            return ctx.Err()
        case <-time.After(backoff.NextDelay(attempt)):
        }
    }
    
    return lastErr
}

// Usage
backoff := &ExponentialBackoff{
    InitialDelay: 100 * time.Millisecond,
    MaxDelay:     5 * time.Second,
    Multiplier:   2.0,
}
err := Retry(ctx, 5, backoff, func() error {
    return apiCall()
})
```

### Worker Pool

```go
type Job func(ctx context.Context) error

type WorkerPool struct {
    workers  int
    jobQueue chan Job
    results  chan error
    wg       sync.WaitGroup
}

func NewWorkerPool(workers, queueSize int) *WorkerPool {
    return &WorkerPool{
        workers:  workers,
        jobQueue: make(chan Job, queueSize),
        results:  make(chan error, queueSize),
    }
}

func (p *WorkerPool) Start(ctx context.Context) {
    for i := 0; i < p.workers; i++ {
        p.wg.Add(1)
        go func() {
            defer p.wg.Done()
            for {
                select {
                case <-ctx.Done():
                    return
                case job, ok := <-p.jobQueue:
                    if !ok {
                        return
                    }
                    p.results <- job(ctx)
                }
            }
        }()
    }
}

func (p *WorkerPool) Submit(job Job) {
    p.jobQueue <- job
}

func (p *WorkerPool) Close() {
    close(p.jobQueue)
    p.wg.Wait()
    close(p.results)
}

// Usage
pool := NewWorkerPool(10, 100)
pool.Start(ctx)

for _, item := range items {
    item := item
    pool.Submit(func(ctx context.Context) error {
        return process(ctx, item)
    })
}

pool.Close()
for err := range pool.Results() {
    if err != nil {
        log.Error(err)
    }
}
```

### Semaphore

```go
type Semaphore struct {
    sem chan struct{}
}

func NewSemaphore(max int) *Semaphore {
    return &Semaphore{sem: make(chan struct{}, max)}
}

func (s *Semaphore) Acquire(ctx context.Context) error {
    select {
    case s.sem <- struct{}{}:
        return nil
    case <-ctx.Done():
        return ctx.Err()
    }
}

func (s *Semaphore) Release() {
    <-s.sem
}

// Usage
sem := NewSemaphore(5)
g, ctx := errgroup.WithContext(ctx)

for _, url := range urls {
    url := url
    g.Go(func() error {
        if err := sem.Acquire(ctx); err != nil {
            return err
        }
        defer sem.Release()
        return fetch(ctx, url)
    })
}
err := g.Wait()
```

### Fan-Out / Fan-In

```go
func FanOutFanIn(ctx context.Context, input []int, workers int) []int {
    jobs := make(chan int, len(input))
    results := make(chan int, len(input))
    
    // Fan-out: start workers
    var wg sync.WaitGroup
    for i := 0; i < workers; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for {
                select {
                case <-ctx.Done():
                    return
                case n, ok := <-jobs:
                    if !ok {
                        return
                    }
                    results <- n * 2 // Process
                }
            }
        }()
    }
    
    // Send jobs
    go func() {
        for _, n := range input {
            jobs <- n
        }
        close(jobs)
    }()
    
    // Wait and close results
    go func() {
        wg.Wait()
        close(results)
    }()
    
    // Fan-in: collect
    var output []int
    for r := range results {
        output = append(output, r)
    }
    return output
}
```

### Rate-Limited Pool

```go
import "golang.org/x/time/rate"

type RateLimitedPool struct {
    sem     *Semaphore
    limiter *rate.Limiter
}

func NewRateLimitedPool(maxConcurrent int, rps float64) *RateLimitedPool {
    return &RateLimitedPool{
        sem:     NewSemaphore(maxConcurrent),
        limiter: rate.NewLimiter(rate.Limit(rps), 1),
    }
}

func (p *RateLimitedPool) Execute(ctx context.Context, fn func() error) error {
    if err := p.limiter.Wait(ctx); err != nil {
        return err
    }
    if err := p.sem.Acquire(ctx); err != nil {
        return err
    }
    defer p.sem.Release()
    return fn()
}

// Usage: max 10 concurrent, 100 req/sec
pool := NewRateLimitedPool(10, 100)
g, ctx := errgroup.WithContext(ctx)

for _, item := range items {
    item := item
    g.Go(func() error {
        return pool.Execute(ctx, func() error {
            return process(item)
        })
    })
}
err := g.Wait()
```

### Middleware Pattern

```go
type Middleware func(Handler) Handler
type Handler func(ctx context.Context, req Request) (Response, error)

func Chain(h Handler, middlewares ...Middleware) Handler {
    for i := len(middlewares) - 1; i >= 0; i-- {
        h = middlewares[i](h)
    }
    return h
}

// Logging middleware
func Logging(logger *slog.Logger) Middleware {
    return func(next Handler) Handler {
        return func(ctx context.Context, req Request) (Response, error) {
            start := time.Now()
            resp, err := next(ctx, req)
            logger.Info("request",
                slog.Duration("duration", time.Since(start)),
                slog.Any("error", err),
            )
            return resp, err
        }
    }
}

// Auth middleware
func Auth(validator TokenValidator) Middleware {
    return func(next Handler) Handler {
        return func(ctx context.Context, req Request) (Response, error) {
            if _, err := validator.Validate(req.Token); err != nil {
                return Response{}, errors.New("unauthorized")
            }
            return next(ctx, req)
        }
    }
}

// Usage
handler := Chain(
    businessHandler,
    Logging(logger),
    Auth(validator),
    RateLimit(limiter),
)
```
