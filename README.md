# prune

<p align="center">
  <img src="prune.png" alt="prune logo" width="200">
</p>

<p align="center">
  <em>Automatically remove dead code from OCaml projects by leveraging the power of .mli files</em>
</p>

---

## ⚠️ Important Warnings

> **This tool automatically deletes code from your project.**
>
> - **Always use version control** - Commit your changes before running `prune`
> - **Review all changes** - Use `--dry-run` first to see what will be removed
> - **Test thoroughly** - Automated removal can miss edge cases
> - **Not for libraries** - Removing exports can break downstream consumers
>
> This tool was developed with significant AI assistance. While we've tested it
> extensively, AI-generated code can have subtle issues. The legal and ethical
> landscape around AI-generated code remains unsettled. See [AI Transparency](#ai-transparency)
> section below.

---

## Why prune?

OCaml's module system with separate interface files (`.mli`) is one of
the language's greatest strengths, allowing you to precisely control
what gets exposed from your implementation. However, as projects
evolve, these interfaces tend to accumulate unused exports—functions,
types, and values that are no longer needed.

**This problem is especially acute in AI-assisted development**, where
  code generation tools often create comprehensive interfaces with
  many exports "just in case." Over time, this leads to significant
  code bloat and maintenance burden.

`prune` solves this by automatically detecting and removing unused
exports from your `.mli` files, along with their corresponding
implementations. This helps you:

- **Reduce code size** by eliminating dead code
- **Improve maintainability** by keeping only what's actually used
- **Enhance API clarity** by showing only the exports that matter

---

## How it works

`prune` uses an iterative approach to remove dead code:

1. **Discovery**: Scans your project for `.mli` files and uses Merlin
   to analyze exports
2. **Analysis**: For each export, checks if it's used anywhere else in
   the codebase (apart from the assoaciated implementation)
3. **Removal**: Removes unused exports from `.mli` files
4. **Iteration**: After removal, the build may reveal new errors
   (e.g., "value required but not provided"). `prune` automatically fixes
   these by removing the corresponding implementations
5. **Convergence**: Continues iterating until the build succeeds with
   no more removable code

This iterative approach is key—removing one piece of dead code often
reveals more dead code that was only kept around to support it. By
automatically handling the cascade of removals, `prune` can achieve
more thorough cleaning than a single-pass approach.

## What makes prune unique for OCaml?

Unlike many dead code tools for other languages, `prune` leverages
OCaml's distinctive module system:

- **Interface-driven**: By analyzing `.mli` files, prune knows exactly
    what's meant to be public API vs internal implementation
- **Type-safe removal**: OCaml's strong typing ensures that if the
    code compiles after removal, it's definitely safe
- **Module-aware**: Handles OCaml's sophisticated module features
    including functors, module types, and nested modules
- **Merlin-powered**: Uses the same tool that powers your editor for
    accurate, project-wide analysis

---

## Installation

```bash
dune build      # compile
dune install    # install the `prune` binary into the current OPAM switch
```

## Basic usage

```bash
# Show what would be removed from the current directory
prune show .

# Show unused exports in specific directory
prune show /path/to/project

# Show unused exports in specific files
prune show lib/foo.mli lib/bar.mli

# Mix files and directories
prune show lib/ src/important.mli

# Remove unused exports (interactive - will ask for confirmation)
prune clean .

# Remove without confirmation (force mode)
prune clean . --force
# or shorter:
prune clean . -f

# Single-pass mode (only one iteration)
prune clean . --step-wise

# Exclude test directories from analysis
prune show . --exclude-dirs test,_build
```

## Commands and options

`prune` has two main commands:

### `prune show` - Display unused exports without removing them
- Safe way to see what would be removed
- No changes are made to your files

### `prune clean` - Remove unused exports
- Actually modifies your files
- Will prompt for confirmation unless `--force` is used

### Common options

| Flag | Purpose | Default |
|------|---------|---------|
| `-f`, `--force` | Force removal without confirmation prompt | off |
| `-s`, `--step-wise` | Single-pass mode (only removes exports once) | off (iterative is default) |
| `--exclude-dirs` | Comma-separated list of directories to exclude | none |
| `-v`, `--verbose` | Increase verbosity (can be repeated: -vv) | off |
| `-h`, `--help` | Display help and exit | — |

## Automatic error fixing

`prune` doesn't just detect unused code—it automatically fixes the
cascade of errors that result from removal:

| Warning/Error | Description | What prune does |
|---------|-------------|-----------------|
| Warning 32 | Unused value declaration | Removes the entire `let` binding |
| Warning 33 | Unused open statement | Removes the `open` statement |
| Warning 34 | Unused type declaration | Removes the entire type declaration |
| Warning 69 | Unused record field | Removes the field or just the `mutable` keyword |
| Signature mismatch | "Value required but not provided" | Removes from `.mli` file |
| Unbound errors | References to removed code | Removes the referencing code too |

The real power comes from the iterative fixing: removing one unused
export often triggers a chain reaction where prune automatically
cleans up all the newly orphaned code.

## Requirements

- OCaml ≥ 5.3 with dune (for full Merlin support)
- Merlin (`ocamlmerlin` in your `$PATH`)

## When to use prune

`prune` is particularly effective for:

- **AI-assisted projects**: Where code generation creates many speculative exports
- **Before using AI assistants**: Smaller codebases mean lower token costs and better AI comprehension
- **Refactoring**: After major changes when old APIs are no longer needed
- **Before releases**: To minimize your public API surface
- **Legacy codebases**: To identify and remove years of accumulated dead code


## Limitations

- The analysis relies on Merlin's project view. Generated code or
  unusual dune rules can hide references
- Like all static analysis tools, `prune` should be used with version
  control. Always review changes before committing

## Contributing

Bug reports and pull requests are welcome. Please run `make test` and
`make fmt` before submitting a patch.

## License

MIT — see LICENSE.md for details.

## Acknowledgements

Many thanks for the [Merlin](https://github.com/ocaml/merlin)
maintainers for an indispensable API that makes OCaml tooling
possible.

## AI Transparency

**This project was developed almost entirely using AI** ([Claude
  Code](https://www.anthropic.com/claude-code) by Anthropic). While
  the tool has been tested extensively and works well in practice,
  users should be aware that:

1. **Technical implications**: AI-generated code may have unique
patterns or subtle bugs. We've used `prune` on itself and other
projects successfully, but thorough testing is always recommended.

2. **Legal uncertainty**: The copyright status, license implications,
and liability for AI-generated code remain legally untested. We cannot
trace which training data influenced specific code patterns.

3. **Practical use**: Despite these unknowns, `prune` has been tested
on real OCaml Projects and provide useful results. The tool is
actively maintained and used in practice.

For deeper context on these issues, see the [Software Freedom
Conservancy](https://sfconservancy.org/blog/2022/feb/03/github-copilot-copyleft-gpl/)
and [FSF
positions](https://www.fsf.org/blogs/licensing/fsf-funded-call-for-white-papers-on-questions-around-copilot/)
on AI-generated code.

**By using this tool, you acknowledge these uncertainties.** As with
  any code modification tool: use version control, review all changes,
  and test thoroughly.
