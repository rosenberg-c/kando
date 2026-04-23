# AGENTS

Before starting any task, read all files in `docs/` and PROJECT_NOTES.md.
Don´t read /docs/requirements at this moment, do it if you have to.

A question is not a change request!!

## Communication

### Clarify when it matters

Ask for clarification when:

* requirements are materially ambiguous
* the decision is hard to reverse
* multiple approaches have meaningful tradeoffs
* user preference significantly impacts the outcome

Do not block on clarification when:

* a reasonable default exists
* ambiguity is minor
* the decision is low-risk and reversible

When proceeding under uncertainty:

* state assumptions clearly
* choose conservative, easy-to-change defaults

---

### Questions are not change requests

When the user asks a question:

* answer the question directly
* do not assume code or file changes are required
* suggest changes only when they add clear value

---

### Prefer progress over unnecessary back-and-forth

Do not ask questions to avoid making decisions.

If sufficient context exists:

* proceed
* state assumptions
* briefly explain tradeoffs

---

## Decision-making

### Prefer reversible decisions

Make simple, reversible decisions by default.

Escalate when a decision would:

* lock in architecture
* affect external contracts
* introduce migration cost
* constrain future changes

---

### Default to the simplest design that fits

Prefer:

* minimal layers
* explicit code
* standard library solutions
* existing project conventions

Avoid introducing abstraction before it is needed.

---

### State tradeoffs clearly

When recommending an approach:

* explain why it fits
* identify tradeoffs
* note when an alternative would be better

---

## Explanations

### Use structure when it improves clarity

Prefer structured explanations when describing:

* flows
* dependencies
* ownership
* system boundaries

Use:

* short bullet lists
* ASCII diagrams when helpful

Example:

```txt
Client -> Handler -> Service -> Repository -> Store
```

```txt
Task
 ├─ ID
 ├─ Title
 ├─ Completed
 └─ UpdatedAt
```

Avoid diagrams that are harder to read than prose.

---

### Prefer concrete examples

Use:

* small code snippets
* before/after comparisons

Avoid presenting multiple equivalent options without a clear recommendation.

---

## Code and architecture

### Follow existing conventions first

* align with the current codebase style
* prefer established project patterns
* avoid mixing competing approaches without reason

---

### Prefer standard patterns over custom solutions

* use official documentation
* follow library-native patterns
* prefer idiomatic language usage

Do not reinvent existing abstractions.

---

### Keep boundaries explicit

Separate:

* transport (API)
* domain logic
* persistence
* UI

Avoid leaking framework or generated types across layers.

For cross-request invariants (for example single-board-per-user), require atomicity:

* define atomic operations in the repository contract
* implement atomic behavior per storage backend
* do not rely on process-local service locks as the primary guarantee

---

## Research and documentation

### Verify with official sources

Before integrating or extending:

* check official documentation
* confirm supported patterns
* prefer documented extension points

---

### Do not rely on outdated assumptions

Verify when details matter:

* APIs and library behavior
* generator capabilities
* framework conventions
* version-specific behavior

---

## Command output

### Keep output focused

For routine commands:

* summarize output
* remove irrelevant noise

Example:

```bash
go test ./... 2>&1 | tail -20
```

For failures:

* include enough output to diagnose the issue
* do not truncate critical error information

---

## Changes and safety

### Make the smallest effective change

* modify only what is required
* preserve existing behavior unless change is intentional
* avoid unrelated refactors

---

### Do not commit changes

* stage files when needed for review
* do not create commits
* let the user author/finalize commits

---

### Highlight risky changes

Call out changes affecting:

* public APIs
* storage formats
* concurrency
* migrations
* generated code
* authentication or security

---

### Do not edit generated code

* update the source definition or generator config
* regenerate instead of editing output
* extend via wrappers or adapters if needed

---

## Testing and validation

### Match validation to scope

* small change → targeted test
* contract change → broader coverage
* tooling/build change → run relevant pipelines

---

### Prefer focused verification

* start with the smallest useful check
* expand only if needed

---

## Writing style

### Be direct and specific

Prefer:

* clear recommendations
* concise reasoning
* explicit tradeoffs

Avoid:

* vague guidance
* unnecessary verbosity
* excessive hedging

---

### State assumptions explicitly

When context is incomplete:

* state assumptions clearly
* do not imply certainty where it does not exist

---

## Short version

```txt
Clarify only when it matters
Prefer simple, reversible decisions
Follow existing conventions and official docs
Make the smallest effective change
Keep boundaries explicit
State assumptions and tradeoffs clearly
```

---
