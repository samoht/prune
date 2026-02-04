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
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
    No unused exports found!




Remove the unused exports:
  $ prune clean . --force
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
  
  
    Iteration 1:
    ✓ No unused code found

Verify the result:
  $ cat lib/doclib.mli
  (** This module tests comprehensive documentation comment removal *)
  
  (* Regular comment before used function *)
  (** This function is actually used *)
  val used : unit -> unit
  
  (* Regular comment that should stay *)
  
  (** Leading doc comment for unused function *)
  val unused_leading : unit -> int
  
  val unused_trailing : int -> int
  (** Trailing doc comment that should be removed *)
  
  (** Leading multi-line doc comment
      with several lines of documentation
      that should all be removed *)
  val unused_mixed : string -> string
  (** Also has a trailing comment *)
  
  (** Complex documentation
      @param () unit parameter
      @return string value
      @since 1.0.0 *)
  val unused_multiline : unit -> string
  (** Post-doc: implementation details *)
  (* Regular comment after *)
  
  (** Documentation for a used function *)
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
