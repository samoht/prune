Test functor handling
=====================

This test verifies prune handles functors correctly. The store library
defines a functor with a KEY module type and Make functor. The main
binary uses Make but never calls debug_dump or to_string.

Prune should NOT remove values from module type signatures, since they
are part of the type definition and cannot be independently removed.

Build the project:

  $ dune build

Run prune (should find no unused exports - module type children are not removable):

  $ prune clean . --dry-run
  Analyzing 1 .mli file
    No unused exports found!

  $ prune clean . --force
  Analyzing 1 .mli file
  
  
    Iteration 1:
    ✓ No unused code found





Verify the build still works after cleanup:

  $ dune build

  $ dune exec ./bin/main.exe
  Found: one (size: 2)
