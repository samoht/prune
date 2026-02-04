Test special file types
=======================

This test verifies prune handles various special file types correctly:
- Empty files
- Files with only comments
- Files without trailing newlines

Build the project:
  $ dune build

Run prune on special files:
  $ prune clean . --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 3 .mli files
    No unused exports found!

Test that empty and comment-only files are handled gracefully:
  $ prune clean lib/empty.mli lib/comments_only.mli --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 2 .mli files
    No unused exports found!
