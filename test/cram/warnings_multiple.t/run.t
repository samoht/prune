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
    Fixed 2 errors
  
    Iteration 3:
    Fixed 1 error
  
    Iteration 4:
  ✓ No more unused code found
  
  Summary: removed 2 exports and 7 implementations in 3 iterations (9 lines total)

Verify cleaned code is empty:
  $ cat lib/mixed.ml
  
  
  
  
  
  
  
  
  

Build should now succeed:
  $ dune build
