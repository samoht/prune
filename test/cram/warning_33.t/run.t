Test Warning 33 (unused open statements)
========================================

This test verifies prune's support for Warning 33 - unused open statements
in both .ml and .mli files.

Let's check what warnings the build shows:
  $ dune build 2>&1 || true
  File "lib/testlib.mli", line 1, characters 0-9:
  1 | open List  (* This open is unused *)
      ^^^^^^^^^
  Error (warning 33 [unused-open]): unused open Stdlib.List.
  
  File "lib/testlib.mli", line 2, characters 0-11:
  2 | open String  (* This open is unused too *)
      ^^^^^^^^^^^
  Error (warning 33 [unused-open]): unused open Stdlib.String.
  File "src/main.ml", line 2, characters 0-11:
  2 | open String
      ^^^^^^^^^^^
  Error (warning 33 [unused-open]): unused open Stdlib.String.
  
  File "src/main.ml", line 3, characters 0-10:
  3 | open Array
      ^^^^^^^^^^
  Error (warning 33 [unused-open]): unused open Stdlib.Array.

Run prune to fix all unused opens:
  $ prune clean . --force
  Analyzing 1 .mli file
  
  
    Iteration 1:
    Fixed 4 errors
  
    Iteration 2:
  prune: internal error, uncaught exception:
         Failure("AST-based item bounds detection failed: No signature item found at position")
         
  [125]

Check that unused opens were removed from .ml files:
  $ cat src/main.ml | grep "open"
  open List

Check that unused opens were removed from .mli files:
  $ cat lib/testlib.mli | grep "open"
  [1]

Build should now succeed:
  $ dune build
