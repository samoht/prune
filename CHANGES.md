# Changes

## v0.1.0 (2025-06-06)

### Features

- Find and remove unused exports from OCaml `.mli` interface files
- Support for cross-module usage detection using merlin's occurrence analysis
- Iterative cleanup mode (`--iterative`) for alternating between `.mli` and `.ml` cleanup
- Interactive confirmation prompts with `--yes` flag for automation
- Dry-run mode (`--dry-run`) to preview changes without modification
- Support for analyzing specific files, directories, or entire projects
- Colored output with progress indicators for better user experience
- Structured logging with configurable verbosity levels

### Implementation

- Uses merlin's outline and occurrences commands for accurate analysis
- Leverages dune's `@ocaml-index` target for cross-module detection
- Detects unused implementations via Warning 32 messages
- Preserves file formatting and only removes targeted declarations
- Handles complex module structures including functors and module types

### Command Line Interface

- `prune` - analyze current directory
- `prune --dry-run` - preview what would be removed
- `prune --yes` - auto-confirm all removals
- `prune --iterative --yes` - perform full dead code elimination
- `prune lib/ src/` - analyze specific directories
- `prune --server` - experimental server mode for better performance

### Known Limitations

- Module type occurrences may not be fully tracked
- Limited support for functors and first-class modules
- Server mode is experimental and may have issues