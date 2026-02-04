Test handling of very long lines
================================

This test verifies that prune can handle functions with extremely long signatures
that exceed typical line length limits.

Build the project:
  $ dune build

Run prune to check handling of long lines:
  $ prune clean . --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
    No unused exports found!

Test verbose mode shows truncation:
  $ prune clean . --dry-run -v 2>&1 | grep -E "(truncated|very_long)" | head -5
