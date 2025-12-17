# Repository Guidelines

## Project Structure & Module Organization
BlueskyClient.jl is a Julia package: `Project.toml` pins dependencies, `src/BlueskyClient.jl` is the entry module, and `CLAUDE.md` states the plan. Treat `atproto/` (pnpm TypeScript monorepo) and `py_atproto/` (MarshalX’s Python SDK plus lexicon tooling) as authoritative references—sync upstream changes and keep local tweaks minimal. Put Julia tests in `test/` beside their fixtures.

## Build, Test, and Development Commands
- `julia --project=. -e 'using Pkg; Pkg.instantiate()'` — install dependencies declared in `Project.toml`.
- `julia --project=. -ie 'using Revise, BlueskyClient'` — start a hot-reload REPL for `src/`.
- `julia --project=. -e 'using Pkg; Pkg.test()'` — run `test/runtests.jl`; keep failures scoped with focused `@testset`s.
- `pnpm -C atproto install && pnpm -C atproto run verify` and `(cd py_atproto && poetry install --with dev,test && poetry run pytest)` — keep the TypeScript and Python references linted, typed, and tested before porting logic.

## Coding Style & Naming Conventions
Use idiomatic Julia style: 4-space indents, `UpperCamelCase` modules (`BlueskyClient.Auth`), `lowercase_with_underscores` functions, and `SCREAMING_SNAKE_CASE` constants that match AT Protocol identifiers; document public APIs with triple-quoted docstrings. Format with `JuliaFormatter.jl` (`julia --project=. -e 'using JuliaFormatter; format("src","test")'`). In `atproto/`, rely on pnpm’s ESLint/Prettier scripts, and in `py_atproto/`, observe Ruff’s 120-character limit plus `poetry run ruff check` and `poetry run mypy`.

## Testing Guidelines
Create or expand `test/runtests.jl` and group scenarios with descriptive `@testset`s. Prefer deterministic fixtures generated from `atproto/lexicons` or curated JSON stored in `test/fixtures/` rather than hitting live services. When porting a feature, mirror assertions from `atproto/packages/*/tests` or `py_atproto/tests/` to retain parity, and add regression tests for every bug fix.

## Commit & Pull Request Guidelines
`atproto` history (`64dc2ed0a Version packages (#4462)`, `dd0fe8d5e [APP-1713] Add Age Assurance config (#4460)`) shows the expected style: short imperative subject, optional ticket tag in brackets, trailing PR number. Reuse that pattern, keep subjects under 72 characters, and explain the “why” plus touched lexicon IDs in the body. Each PR must link related issues, summarize testing across Julia/pnpm/poetry targets, and attach screenshots or REPL snippets for user-facing changes.

## Security & Configuration Tips
Never commit credentials or DID signing keys; source them from environment variables (e.g., `BSKY_HANDLE`, `BSKY_PASSWORD`) or ignored `.env` files. Verify upstream commit hashes before trusting new lexicons, isolate dependency bumps for auditability, and rotate tokens immediately if logs or fixtures expose them.
