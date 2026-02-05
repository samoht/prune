Test mutually recursive types with unused constructors
======================================================

This test has three mutually recursive types (expr, cond, stmt) each
containing an Unused_debug_* constructor that triggers warning 37.
Prune must remove the unused constructors without breaking the mutual
recursion structure.

Build fails due to unused constructors:

  $ dune build

Run prune to fix:

  $ prune clean . --force
  Analyzing 1 .mli file
  
  
    Iteration 1:
  Removing 1 unused exports...
  ✓ lib/lang.mli
  
    Iteration 2:
  ✓ No more unused code found
  
  Summary: removed 1 export and 0 implementations in 1 iteration (1 line total)

Verify the constructors were removed and build succeeds:

  $ dune build

  $ dune exec ./bin/main.exe
  3
  Result: 42
  Expr: (1 + (2 * 3))
