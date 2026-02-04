Test: Trailing documentation comment removal
============================================

This test verifies that trailing documentation comments are correctly removed
along with their associated items. Trailing comments (with no blank line 
separation) belong to the item they follow, not the next item.

Build the test project:

  $ dune build
  $ dune build @ocaml-index

Initial check - see what prune detects as unused:

  $ prune clean . --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
    No unused exports found!

Remove the unused exports:

  $ prune clean . --force
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
  
  
    Iteration 1:
    ✓ No unused code found

Verify that items and their trailing comments were removed:

  $ cat lib/test.mli
  (** A module for testing trailing documentation comment removal *)
  
  val used : int -> int
  
  val unused1 : int -> int
  (** This trailing doc comment should be removed with unused1 *)
  
  val unused2 : string -> string
  (** This trailing doc comment should be removed with unused2 *)
  
  (** This comment is for a used value, so it stays *)
  val also_used : string -> string
  
  val unused3 : float -> float
  (** This trailing doc comment should be removed with unused3 *)
