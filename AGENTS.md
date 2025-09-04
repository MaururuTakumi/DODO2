# Repository Guidelines

## Project Structure & Module Organization
- Use a clear layout: `src/` (code), `tests/` (unit/integration), `scripts/` (one‑off tooling), `docs/` (notes/specs), `assets/` (static files). Add subfolders as needed per domain.
- Keep executables/CLIs in `bin/` or `cmd/`, and library code in `src/<module>`; avoid mixing app code and tests.
- Example:
  - `src/feature_x/…`
  - `tests/feature_x/test_api.*`
  - `scripts/dev/seed.*`

## Build, Test, and Development Commands
- Prefer repository scripts over global tools. Typical patterns (use what matches present files):
  - If `Makefile`: `make setup` (install), `make test` (run tests), `make build` (compile/package), `make dev` (watch mode).
  - If `package.json`: `npm ci`, `npm run build`, `npm test`, `npm run dev`.
  - If `pyproject.toml`: `poetry install`, `poetry run pytest`, `poetry run <entrypoint>`.
- Add new commands in the same place (Make or npm/poetry) with descriptive names.

## Coding Style & Naming Conventions
- Format on save; enforce via CI. Suggested tooling: Prettier (JS/TS), Black + isort (Python).
- Indentation: 2 spaces (web/TS), 4 spaces (Python). Max line length: 100.
- Names: `snake_case` for files and functions, `PascalCase` for classes/types, `kebab-case` for CLI names and folders.
- Keep modules small; one responsibility per file. Avoid cyclic imports.

## Testing Guidelines
- Mirror `src/` in `tests/`. Name tests `test_*.py` (pytest) or `*.spec.ts`/`*.test.ts` (Jest/Vitest).
- Aim for ≥80% line coverage; add regression tests for every bug fix.
- Include fast unit tests by default; mark slow/integration tests with a tag or filename suffix.

## Commit & Pull Request Guidelines
- Use Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`.
  - Examples: `feat(auth): add PKCE flow`, `fix(api): handle 404 on fetchUser`.
- PRs: concise description, linked issue (`Closes #123`), screenshots/logs for UX or DX changes, and test/coverage updates when behavior changes.
- Keep PRs small and focused; include migration notes in `docs/` when needed.

## Security & Configuration
- Never commit secrets; use `.env` and add `.env.example` with safe defaults. Document required env vars in `docs/config.md`.
- Review dependencies; pin versions and avoid unused packages. Add basic input validation on all public entrypoints.

