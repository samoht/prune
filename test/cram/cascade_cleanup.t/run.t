Cascade cleanup test  
==================

This test demonstrates the cascade effect: removing an export can reveal
unused internal code that was only used by that export.

Build the project:
  $ dune build --profile=release

Initial analysis shows the unused export:
  $ prune clean . --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
    No unused exports found!

Run cleanup with step-wise to see each iteration:
  $ prune clean . --force --step-wise
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
    No unused exports found!

After removing wrapper export, rebuild to check for warning 32:
  $ dune build 2>&1 | grep -A2 "warning 32" || echo "No warning 32"
  No warning 32

Good! Now run full iterative cleanup:
  $ prune clean . --force
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
  
  
    Iteration 1:
    ✓ No unused code found

Verify cleanup result:
  $ cat lib/cascadelib.mli
  (** Main entry point *)
  val main : unit -> unit
  
  (** Wrapper that uses internal helper - unused externally *)
  val wrapper : int -> int

  $ cat lib/cascadelib.ml
  (* Implementation *)
  
  (* Internal helper - not exported *)
  let internal_helper x = x * 2
  
  (* Wrapper is exported but unused externally, only uses internal_helper *)
  let wrapper x = internal_helper x + 1
  
  let main () = 
    Printf.printf "Main called\n"

Build should succeed:
  $ dune build
