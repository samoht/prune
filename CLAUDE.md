# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`prune` is an OCaml utility that automatically removes unused exports from `.mli` interface files in dune projects. It uses existing OCaml tooling (`ocamlmerlin`) to analyze dependencies and symbol usage.

## Quick Start for Development

```bash
# Build and format after making changes
dune build && dune fmt --auto

# Run tests
dune runtest

# Install locally for testing
dune install
```

## Critical Development Rules

- **Code Exploration**: always read and write mli first before looking at the code
- **Error handling**: Use `err_*` helper functions for consistent error messages (see `docs/GUIDELINES.md` for pattern)
- **Library architecture**: Library code never calls `exit` directly - only returns errors for main.ml to handle
- **Testing**: NEVER run `dune`, `ocamlmerlin`, or `prune` commands directly in *.t (cram) test directories - these are test fixtures accessed only through `dune runtest`. DO NOT CD into test/cram directories to run commands! See `test/cram/README.md` for proper cram test commands.
- **Comments**: Use normal comments `(* *)` in .ml files; doc comments `(** **)` only in .mli files
- **Dependencies**: Uses Re library for regex patterns, not String.contains

## Documentation Organization

- `docs/GUIDELINES.md` - Coding standards and error handling patterns
- `test/cram/README.md` - Cram test standards (follow these guidelines strictly)
- `docs/DEBUGGING.md` - Merlin debugging and troubleshooting

## Task Tracking

The project uses a `TODO.md` file to track ongoing tasks, bugs, and feature requests. When tasks are completed, remove them from TODO.md rather than marking them with [x].