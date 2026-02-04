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
  Analyzing 3 .mli files
  lib/no_newline.mli:1:0-29: unused value no_newline
  Found 1 unused exports

Test that empty and comment-only files are handled gracefully:
  $ prune clean lib/empty.mli lib/comments_only.mli --dry-run
  Analyzing 2 .mli files
    No unused exports found!
