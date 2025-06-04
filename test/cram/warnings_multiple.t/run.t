Test Mixed Warnings (32, 33, 34)
================================

This test verifies prune handles multiple warning types together.

Build shows multiple warnings:
  $ dune build 2>&1 | grep -E "warning (32|33|34)" | head -5
  Error (warning 33 [unused-open]): unused open Stdlib.Printf.
  Error (warning 34 [unused-type-declaration]): unused type unused_type.
  Error (warning 32 [unused-value-declaration]): unused value unused_fun.
  Error (warning 32 [unused-value-declaration]): unused value internal_only.

Run prune to clean all warnings:
  $ prune clean . --force
  Analyzing 1 .mli file
  
  
    Iteration 1:
    Fixed 4 errors
  
    Iteration 2:
    Removed 2 exports
  prune: [WARNING] Could not find value binding at lib/mixed.ml:6:4 (No value binding found at position), falling back to item detection
  prune: internal error, uncaught exception:
         Failure("AST-based item bounds detection failed: No structure item found at position")
         
  [125]

Verify cleaned code is empty:
  $ cat lib/mixed.ml
  
  open List    (* Used *)
  
  type used_type = int
  
  let used_fun x = map (fun y -> y + 1) x

Build should now succeed:
  $ dune build
  File "lib/mixed.ml", line 4, characters 0-20:
  4 | type used_type = int
      ^^^^^^^^^^^^^^^^^^^^
  Error (warning 34 [unused-type-declaration]): unused type used_type.
  
  File "lib/mixed.ml", line 6, characters 4-12:
  6 | let used_fun x = map (fun y -> y + 1) x
          ^^^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value used_fun.
  [1]
