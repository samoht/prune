Test CLI argument parsing
=========================

Test help output:

  $ prune --help=plain
  NAME
         prune - Find and remove unused exports in OCaml projects
  
  SYNOPSIS
         prune [COMMAND] …
  
  DESCRIPTION
         prune is a tool that automatically removes unused exports from OCaml
         .mli interface files.
  
  COMMANDS
         clean [OPTION]… [PATH]…
             Find and remove unused exports in OCaml .mli files (default)
  
         doctor [OPTION]… [MLI_FILE]
             Run diagnostics to check merlin and build setup
  
         show [OPTION]… [PATH]…
             Show symbol occurrence statistics
  
  COMMON OPTIONS
         --help[=FMT] (default=auto)
             Show this help in format FMT. The value FMT must be one of auto,
             pager, groff or plain. With auto, the format is pager or plain
             whenever the TERM env var is dumb or undefined.
  
         --version
             Show version information.
  
  EXIT STATUS
         prune exits with:
  
         0   on success.
  
         123 on indiscriminate errors reported on standard error.
  
         124 on command line parsing errors.
  
         125 on unexpected internal errors (bugs).
  
  EXAMPLES
         Remove unused exports:
  
           prune clean
  
         Run diagnostics:
  
           prune doctor
  
  SEE ALSO
         prune-clean(1), prune-doctor(1)
  


Test version output:

  $ prune --version
  dev

Test invalid arguments:

  $ prune --invalid-option
  Usage: prune [--help] [COMMAND] …
  prune: unknown option --invalid-option
  [124]

Test clean subcommand help:

  $ prune clean --help=plain | head -30
  NAME
         prune-clean - Find and remove unused exports in OCaml .mli files
         (default)
  
  SYNOPSIS
         prune clean [OPTION]… [PATH]…
  
  DESCRIPTION
         clean analyzes OCaml .mli interface files to find unused exports.
  
         It can analyze an entire dune project (default) or specific .mli
         files.
  
  ARGUMENTS
         PATH
             Specific .mli files or directories to analyze instead of entire
             project
  
  OPTIONS
         --color=WHEN (absent=auto)
             Colorize the output. WHEN must be one of auto, always or never.
  
         --dry-run
             Only report what would be removed, don't actually remove
  
         --exclude=DIR
             Directories to exclude from occurrence counting (e.g., test/,
             _build/). Symbols used only in excluded directories will be
             reported separately.
  

Test verbose mode with non-existent file:

  $ prune clean nonexistent.mli
  Error: nonexistent.mli: No such file or directory
  [1]

Test that multiple non-existent paths show warnings:

  $ prune clean path1 path2 path3 --dry-run 2>&1
  Error: path1: No such file or directory
  Error: path2: No such file or directory
  Error: path3: No such file or directory
  [1]

Test doctor subcommand:

  $ prune doctor --help=plain | head -20
  NAME
         prune-doctor - Run diagnostics to check merlin and build setup
  
  SYNOPSIS
         prune doctor [OPTION]… [MLI_FILE]
  
  DESCRIPTION
         doctor checks your environment and project setup to diagnose potential
         issues with prune.
  
         It verifies that merlin is installed, properly configured, and can
         find occurrences across your project.
  
  ARGUMENTS
         MLI_FILE
             Sample .mli file to test merlin occurrences
  
  OPTIONS
         --color=WHEN (absent=auto)
             Colorize the output. WHEN must be one of auto, always or never.
