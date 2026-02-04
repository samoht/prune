Test Warning 32 (unused value declarations)
===========================================

This test verifies prune's support for Warning 32 - unused value declarations.

Build shows warning 32 for unexported values:
  $ dune build 2>&1 | grep -E "warning 32" || echo "No warnings in interface"
  Error (warning 32 [unused-value-declaration]): unused value internal_only.

Run prune in dry-run mode:
  $ prune clean . --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
  Error: Build failed:
  File "lib/test.ml", line 3, characters 4-17:
  3 | let internal_only x = x * 2
          ^^^^^^^^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value internal_only.
  [1]

Run prune with --force to remove unused values:
  $ prune clean . --force
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
  
  
    Iteration 1:
    Fixed 1 error
  
    Iteration 2:
  ✓ No more unused code found
  
  Summary: removed 0 exports and 1 implementation in 1 iteration (1 line total)

Verify exports were removed:
  $ cat lib/test.mli
  val used_fun : int -> int
  val unused_fun : unit -> int
  (* internal_only is not exported *)

Verify implementations were also cleaned:
  $ cat lib/test.ml
  let used_fun x = x + 1
  let unused_fun () = 42
