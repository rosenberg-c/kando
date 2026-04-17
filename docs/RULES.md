# Go Engineering Rules

## 1. Do not take addresses of range loop variables

Range variables are reused across iterations.

**Bad:**

```go
for _, v := range slice {
    return &v
}
```

**Good:**

```go
for i := range slice {
    return &slice[i]
}
```

---

## 2. Build file paths with `filepath.Join`

* Avoid string concatenation for paths
* Ensures cross-platform correctness

```go
path := filepath.Join(basePath, "file.json")
```

---

## 3. Choose values vs pointers based on semantics

Do not default to one or the other.

Use **values** when:

* data is small and immutable
* you want clear ownership and no shared mutation

Use **pointers** when:

* mutation is required
* structs are large
* optional fields are needed (`nil`)
* identity matters

If returning pointers:

* ensure they point to stable memory (not loop variables)

---

## 4. Validate invariants at boundaries

* enforce uniqueness (IDs, usernames) on create
* validate inputs before mutating state
* return explicit domain errors

```go
var ErrAlreadyExists = errors.New("already exists")
```

---

## 5. Treat persistence as slow and failure-prone

* expect I/O to fail
* wrap errors with context

```go
return fmt.Errorf("save user: %w", err)
```

* avoid unnecessary full read–modify–write cycles

---

## 6. Protect shared state with synchronization

* use `sync.Mutex` or `sync.RWMutex` when concurrent access is possible
* file-backed storage is not concurrency-safe by default

---

## 7. Design for testability with dependency injection

Prefer dependency injection at boundaries.

**Bad:**

```go
NewRepo(path string)
```

**Good:**

```go
NewRepo(store Store)
```

Guidelines:

* avoid hardcoding file paths, globals, or environment access
* inject dependencies explicitly
* use real implementations in tests when practical

---

## 8. Document exported symbols meaningfully

* exported types and functions should generally have comments
* comments should explain behavior, not restate names

Focus on:

* error conditions
* side effects
* concurrency guarantees
* invariants and assumptions

**Bad:**

```go
// GetByID gets by ID
```

**Good:**

```go
// GetByID returns ErrNotFound if no user with the given ID exists.
```

---

## 9. Nil slices are valid

* returning `nil` slices is idiomatic
* only return empty slices when required by JSON/API contracts

---

## 10. Use `context.Context` at boundaries

Accept `context.Context` in functions that:

* perform I/O
* may block
* are request-scoped

```go
func (r *Repo) GetByID(ctx context.Context, id string) (User, error)
```

Rules:

* do not store context in structs
* pass it through call chains
* use only for cancellation, deadlines, and request-scoped values

---

## 11. Use interfaces deliberately

Use interfaces only when they provide real value.

Use interfaces when:

* you need to decouple a consumer from an implementation
* multiple implementations are expected
* you want to isolate external dependencies (I/O, storage, APIs)

Avoid interfaces when:

* there is only one implementation
* they are introduced “just in case”
* they duplicate a concrete type without adding value

Prefer:

* defining interfaces at the point of use (consumer)
* small, focused interfaces
* concrete types until abstraction is needed

**Bad:**

```go
type UserRepository interface {
    Create(...)
    Update(...)
    Delete(...)
    Get(...)
}
```

**Better:**

```go
type UserGetter interface {
    GetByID(ctx context.Context, id string) (User, error)
}
```

---

## 12. Separate domain, transport, and storage models

Do not couple core domain structs to:

* JSON shape
* database schema
* OpenAPI-generated types

Use mapping at boundaries:

```txt
[Transport DTO] <-> [Domain Model] <-> [Storage Model]
```

---

## 13. Return errors, don’t panic

* use `error` for expected failures
* panic only for truly unrecoverable programmer errors

---

## 14. Keep functions small and explicit

* prefer simple, readable functions over clever abstractions
* make data flow obvious
* avoid hidden side effects

---

## 15. Be explicit about concurrency

Do not introduce goroutines without clear ownership.

Always answer:

* who starts it
* who stops it
* how errors are handled

---

## 16. Favor composition over inheritance-style patterns

* embed structs for reuse
* avoid deep abstraction hierarchies

---

## 17. Logging is not error handling

* return errors to callers
* log only at boundaries (HTTP layer, CLI entrypoint, etc.)

---

## 18. Treat file-backed storage as a prototype

File storage is not suitable for:

* high concurrency
* large datasets
* distributed systems

Design so it can be replaced later.

---

## 19. Test behavior, not implementation

Write tests that validate observable behavior.

Prefer:

* testing public APIs and behavior
* verifying outputs, errors, and side effects
* real implementations when fast and deterministic

Avoid:

* asserting on internal/private details
* unnecessary mocking
* tests dependent on timing, globals, or external systems

Guidelines:

* use table-driven tests for logic
* test errors explicitly with `errors.Is`
* keep tests fast and deterministic
* if code is hard to test, simplify the design

---
