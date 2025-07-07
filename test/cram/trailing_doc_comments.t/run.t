Test: Trailing documentation comments after removed values
==========================================================

This test verifies that trailing documentation comments are properly removed
when the values they document are removed.

Build the test project:

  $ dune build
  $ dune build @ocaml-index

Initial check - see what prune detects as unused:

  $ prune clean . --dry-run
  Analyzing 1 .mli file
  lib/test.mli:5:0-24: unused value unused1
  lib/test.mli:8:0-30: unused value unused2
  lib/test.mli:15:0-28: unused value unused3
  Found 3 unused exports

Remove the unused exports:

  $ prune clean . --force
  Analyzing 1 .mli file
  
  
    Iteration 1:
    Removed 3 exports
    Fixed 3 errors
  
    Iteration 2:
  ✓ No more unused code found
  
  Summary: removed 3 exports and 3 implementations in 1 iteration (11 lines total)

Verify that trailing comments were removed along with the values:

  $ cat lib/test.mli
  (** A module for testing trailing documentation comment removal *)
  
  val used : int -> int
  
  val also_used : string -> string
