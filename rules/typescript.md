---
paths:
  - "*.ts"
  - "*.tsx"
  - "*.js"
  - "*.jsx"
  - "tsconfig.json"
---
# TypeScript Conventions

## Compiler

- Set `"strict": true` in tsconfig — no exceptions
- Avoid `any`; if unavoidable, add a comment explaining why
- Prefer `unknown` over `any` at system boundaries (user input, API responses)

## Types

- Use `interface` for object shapes that may be extended
- Use `type` for unions, intersections, and aliases
- No `enum` — use `as const` objects for better tree-shaking and type inference

## Null Safety

- Prefer optional chaining (`?.`) over manual null guards
- Use nullish coalescing (`??`) over `||` when falsy values are valid

## Imports

- Named imports over default exports — aids discoverability and refactoring
- Avoid barrel files (`index.ts` re-exporting everything) — they slow build tools and obscure dependencies

## React (when using .tsx)

- Functional components only — no class components
- Hooks over HOCs for shared logic
- Keep components small; extract logic into custom hooks

## Formatting and Linting

- Prettier for formatting, ESLint for logic rules — do not configure them to overlap
- Run both before commit

## Async

- `async/await` over raw promise chains
- Handle errors at system boundaries — not inside every utility function
