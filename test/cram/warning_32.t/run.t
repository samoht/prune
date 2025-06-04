Test Warning 32 (unused value declarations)
===========================================

This test verifies prune's support for Warning 32 - unused value declarations.

Build shows warning 32 for unexported values:
  $ dune build 2>&1 | grep -E "warning 32" || echo "No warnings in interface"
  Error (warning 32 [unused-value-declaration]): unused value internal_only.

Run prune in dry-run mode:
  $ prune clean . --dry-run
  Analyzing 1 .mli file
  Error: Build failed:
  File "lib/test.ml", line 3, characters 4-17:
  3 | let internal_only x = x * 2
          ^^^^^^^^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value internal_only.
  [1]

Run prune with --force to remove unused values:
  $ prune clean . --force
  Analyzing 1 .mli file
  
  
    Iteration 1:
    Fixed 1 error
  
    Iteration 2:
    Removed 2 exports
    Fixed 2 errors
  
    Iteration 3:
  ✓ No more unused code found
  
  Summary: removed 2 exports and 3 implementations in 2 iterations (6 lines total)

Verify exports were removed:
  $ cat lib/test.mli

Verify implementations were also cleaned:
  $ cat lib/test.ml
