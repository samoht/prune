Comprehensive Documentation Comment Removal Test
================================================

This test verifies proper removal of documentation comments in all positions:
- Leading doc comments (before declarations)
- Trailing doc comments (after declarations)
- Multi-line doc comments
- Mixed leading and trailing comments
- Preservation of regular comments

Build the project:
  $ dune build

Check what will be removed:
  $ prune clean . --dry-run
  Analyzing 1 .mli file
  lib/doclib.mli:10:0-32: unused value unused_leading
  lib/doclib.mli:12:0-32: unused value unused_trailing
  lib/doclib.mli:18:0-35: unused value unused_mixed
  lib/doclib.mli:25:0-37: unused value unused_multiline
  Found 4 unused exports




Remove the unused exports:
  $ prune clean . --force
  Analyzing 1 .mli file
  
  
    Iteration 1:
    Removed 4 exports
    Fixed 4 errors
  
    Iteration 2:
  ✓ No more unused code found
  
  Summary: removed 4 exports and 4 implementations in 1 iteration (22 lines total)

Verify the result:
  $ cat lib/doclib.mli
  (** This module tests comprehensive documentation comment removal *)
  
  (* Regular comment before used function *)
  (** This function is actually used *)
  val used : unit -> unit
  
  val used_with_docs : int -> int
  (* This comment stays too *)
  
  (* Final regular comment *)

The test demonstrates that prune correctly handles documentation comments:

For USED functions (used, used_with_docs):
- The declarations are preserved
- Their doc comments are preserved
- Regular comments near them are preserved

For UNUSED functions (unused_leading, unused_trailing, unused_mixed, unused_multiline):
- The declarations are removed
- Leading doc comments are removed
- Trailing doc comments are removed (this was previously broken)
- Multi-line doc comments are removed
- Only floating regular comments remain
