# PROJECT_NOTES.md

## Overview

Todo application with:

* Go backend (HTTP API)
* macOS app (Swift)
* CLI app (Go)

All clients communicate through the same API.

```txt id="ov6w9r"
[macOS App] ─┐
             ├─> HTTP API (Go)
[CLI App]   ─┘        ↓
                  Service
                    ↓
                 Repository
                    ↓
               SQLite (pure Go)
```

---

## Core Principles

### 1. OpenAPI becomes the contract

* Backend may be developed first
* Once endpoints stabilize, `openapi.yaml` is the source of truth
* All clients must follow the spec

---

### 2. Generated code is read-only

* Never edit generated code
* Update spec → regenerate
* Extend via adapters

---

### 3. Strict separation of models

```txt id="1tgb03"
[OpenAPI DTO] <-> [Domain Model] <-> [Storage Model]
```

---

### 4. All clients use the same API

```txt id="lrl5zb"
CLI      ─┐
          ├─> HTTP API → Service → Repo → SQLite
macOS App ─┘
```

---

## Project Structure

```txt id="0m1ry7"
todo-app/
├─ api/
│  └─ openapi.yaml
│
├─ apps/
│  ├─ server/
│  │  └─ main.go
│  ├─ cli/
│  │  └─ main.go
│  └─ macos/
│
├─ internal/
│  ├─ domain/
│  ├─ service/
│  ├─ repo/
│  ├─ store/sqlite/
│  ├─ api/generated/
│  ├─ api/handlers/
│  └─ api/mapping/
│
├─ migrations/
├─ generated/
├─ scripts/
├─ docs/
├─ Makefile
├─ go.mod
└─ README.md
```

---

## Layer Responsibilities

### API Layer

* implements generated interfaces
* maps DTO ↔ domain
* maps errors → HTTP

---

### Service Layer

* business logic only
* no HTTP or DB knowledge

---

### Repository Layer

* defines interfaces
* abstracts storage

---

### Store Layer (SQLite)

* implements repository
* contains SQL
* no business logic

---

## OpenAPI Workflow

### Spec location

```txt id="mbhw21"
/api/openapi.yaml
```

---

### Development phases

#### Phase 1 — exploration

* implement backend manually
* CLI may use raw HTTP

#### Phase 2 — stabilization

* define/refine OpenAPI spec
* align handlers

#### Phase 3 — contract-first

* generate clients
* spec becomes canonical

---

### Go generation

Tool:

* oapi-codegen

```bash id="z70yfh"
make generate
```

---

### Swift generation

Tool:

* Swift OpenAPI Generator

Run from `apps/macos`.

---

## Makefile Workflow

The Makefile is the **entrypoint for all development tasks**.

### Core commands

```bash id="r03w7g"
make generate   # generate OpenAPI Go code
make build      # build server + CLI
make run        # run server
make run-cli    # run CLI
make test       # run tests
make fmt        # format code
```

---

### Development loop

```bash id="y5mw85"
make dev
```

Equivalent to:

```txt id="d5d2ri"
generate → build → run server
```

---

### When API changes

```bash id="y38c6m"
make generate
make build
```

---

### Notes

* All generation must go through `make generate`
* Do not run generators manually
* Keep Makefile as the single source of truth for tooling

---

## Storage: SQLite (Pure Go)

### Driver

```txt id="dqk7sv"
modernc.org/sqlite
```

* no CGO
* easier builds
* good for CLI + backend

---

### Rules

* single DB file per environment
* all access via repository/store
* no direct SQL outside store

Enable WAL:

```sql id="xv9o1t"
PRAGMA journal_mode = WAL;
```

---

## Data Flow

```txt id="vbd96v"
Client → HTTP → Handler → Service → Repo → SQLite
```

---

## Error Handling

```go id="b9a9g0"
var (
    ErrNotFound      = errors.New("not found")
    ErrAlreadyExists = errors.New("already exists")
)
```

---

## Validation

```txt id="6ptqyw"
OpenAPI → request validation
Service → business rules
```

---

## Testing

```txt id="m1fq7k"
Domain     → unit
Service    → unit
Repository → integration (SQLite)
API        → handler tests
```

Rules:

* test behavior, not implementation
* prefer real DB
* keep tests fast

---

## Concurrency

* SQLite handles most concurrency
* repository must be safe
* avoid long transactions

---

## CLI Notes

* use HTTP API
* may start with raw HTTP
* can migrate to generated client

---

## macOS Notes

* use generated client
* avoid manual networking

---

## Common Mistakes

### Mixing layers

```txt id="ng8ti3"
Bad: Handler → DB
Good: Handler → Service → Repo → Store
```

---

### Using DTOs in domain

```txt id="kwgxz7"
Bad: api.Todo
Good: domain.Todo
```

---

### Editing generated code

Never modify generated files.

---

### Over-abstracting early

* start concrete
* introduce interfaces later

---

## Development Workflow

```txt id="zv2n2g"
1. Implement backend
2. Update OpenAPI spec (when stable)
3. make generate
4. Implement adapters/services
5. make test
6. Update clients
```

---

## Short Version

```txt id="gy9mbx"
Backend first → spec becomes canonical
OpenAPI = contract
Generated code = read-only
SQLite (pure Go)
Makefile = entrypoint for all tasks
CLI + macOS use same API
Test behavior, not implementation
```

---
