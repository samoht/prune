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
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
  
  
    Iteration 1:
    Fixed 4 errors
  
    Iteration 2:
  ✓ No more unused code found
  
  Summary: removed 0 exports and 4 implementations in 1 iteration (4 lines total)

Verify cleaned code is empty:
  $ cat lib/mixed.ml
  
  open List    (* Used *)
  
  type used_type = int
  
  
  let used_fun x = map (fun y -> y + 1) x
  
  

Build should now succeed:
  $ dune build
