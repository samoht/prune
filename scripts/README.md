# Git Hook Setup Scripts

This directory contains scripts to set up git hooks for OCaml projects.

## setup-hooks.sh

This script installs pre-commit and commit-msg hooks that ensure code quality before commits.

### What the hooks do:

**Pre-commit hook:**
1. **Dune build** - Ensures the project builds successfully
2. **Dune fmt** - Checks and enforces code formatting
3. **Dune test** - Runs all tests
4. **Merlint** - Runs the project's own merlint linter (if available)
5. **Prune** - Checks for unused code in lib/ and bin/ directories (if prune is installed)

**Commit-msg hook:**
- Checks for AI attributions in commit messages and rejects them

### Installation

Run from the project root:

```bash
./scripts/setup-hooks.sh
```

### Notes

- The hooks are installed in `.git/hooks/` which is not tracked by git
- You need to run the setup script on each clone of the repository
- To bypass the pre-commit hook in emergencies: `git commit --no-verify`
- The script uses the project's own merlint via `dune exec -- merlint`
- For the merlint project itself: Use `--no-verify` until we migrate from Printf to Fmt