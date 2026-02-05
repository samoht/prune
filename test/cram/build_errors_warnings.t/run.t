Test Build Failures with Warnings
=================================

When there are build errors alongside warnings, prune should fail gracefully.

Prune should fail when project doesn't build:
  $ prune clean . --dry-run 2>&1 | head -3
  Analyzing 0 .mli files
  Error: Build failed:
  File "lib/error.ml", line 3, characters 12-23:
