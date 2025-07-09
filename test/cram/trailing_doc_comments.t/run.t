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
  Analyzing 1 .mli file
  lib/test.mli:5:0-24: unused value unused1
  lib/test.mli:8:0-30: unused value unused2
  lib/test.mli:14:0-28: unused value unused3
  Found 3 unused exports

Remove the unused exports:

  $ prune clean . --force
  Analyzing 1 .mli file
  
  
    Iteration 1:
  Removing 3 unused exports...
  ✓ lib/test.mli
    Fixed 3 errors
  
    Iteration 2:
  ✓ No more unused code found
  
  Summary: removed 3 exports and 3 implementations in 1 iteration (9 lines total)

Verify that items and their trailing comments were removed:

  $ cat lib/test.mli
  (** A module for testing trailing documentation comment removal *)
  
  val used : int -> int
  
  
  
  
  
  
  
  (** This comment is for a used value, so it stays *)
  val also_used : string -> string
  
  
