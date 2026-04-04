---
paths:
  - "*.go"
  - "go.mod"
  - "go.sum"
---
# Go Conventions

## Formatting

- Run `gofmt` and `goimports` before every commit — non-negotiable
- `goimports` handles both import ordering and formatting in one pass

## Error Handling

- Check every error return — no `_` for errors unless explicitly documented why
- Wrap errors with context: `fmt.Errorf("op failed: %w", err)`
- Return errors to the caller; log only at the outermost boundary

## Interfaces

- Define interfaces at the consumer site, not the provider
- Keep interfaces small — 1 to 3 methods; larger interfaces indicate wrong abstraction
- Accept interfaces, return concrete types

## Naming

- MixedCaps, not underscores (`httpClient`, not `http_client`)
- Short variable names in small scopes (`i`, `v`, `err`) are idiomatic
- Exported names must have doc comments

## Concurrency

- Prefer channels for communication, mutexes for state protection
- Pass `context.Context` as the first argument for cancellation and deadlines
- Always document goroutine ownership — who creates it, who stops it

## Testing

- Table-driven tests for multiple input cases
- Call `t.Helper()` inside test helper functions to get accurate failure line numbers
- Use `testify/assert` only if the team has standardized on it; stdlib is sufficient

## Modules

- Run `go mod tidy` after adding or removing dependencies
- Vendor dependencies (`go mod vendor`) when reproducible builds are required
- No `init()` functions unless there is no alternative — they make initialization order invisible
