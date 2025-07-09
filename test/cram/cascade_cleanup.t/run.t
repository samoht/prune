Cascade cleanup test  
==================

This test demonstrates the cascade effect: removing an export can reveal
unused internal code that was only used by that export.

Build the project:
  $ dune build --profile=release

Initial analysis shows the unused export:
  $ prune clean . --dry-run
  Analyzing 1 .mli file
  lib/cascadelib.mli:5:0-24: unused value wrapper
  Found 1 unused exports

Run cleanup with step-wise to see each iteration:
  $ prune clean . --force --step-wise
  Analyzing 1 .mli file
  lib/cascadelib.mli:5:0-24: unused value wrapper
  Found 1 unused exports
  Removing 1 unused exports...
  ✓ lib/cascadelib.mli

After removing wrapper export, rebuild to check for warning 32:
  $ dune build 2>&1 | grep -A2 "warning 32" || echo "No warning 32"
  Error (warning 32 [unused-value-declaration]): unused value wrapper.

Good! Now run full iterative cleanup:
  $ prune clean . --force
  Analyzing 1 .mli file
  
  
    Iteration 1:
    Fixed 1 error
  
    Iteration 2:
    Fixed 1 error
  
    Iteration 3:
  ✓ No more unused code found
  
  Summary: removed 0 exports and 2 implementations in 2 iterations (5 lines total)

Verify cleanup result:
  $ cat lib/cascadelib.mli
  (** Main entry point *)
  val main : unit -> unit
  
  

  $ cat lib/cascadelib.ml
  
  
  
  
  
  
  
  
  let main () = 
    Printf.printf "Main called\n"

Build should succeed:
  $ dune build
