Test multiple libraries with cross-dependency cascade
=====================================================

This test has two libraries:
- core_types: shared types with format_id, parse_id, debug_id
- service: uses core_types, has unused_format and unused_parse_and_format

The cascade: unused_format/unused_parse_and_format in service use
format_id and parse_id from core_types. Once service's unused functions
are removed, format_id and parse_id in core_types become unused too.
debug_id is unused by anything.

This tests that prune handles cross-library cascading cleanup.

Build fails:

  $ dune build

Run prune:

  $ prune clean . --force
  Analyzing 2 .mli files
  
  
    Iteration 1:
  Removing 3 unused exports...
  ✓ lib_b/service.mli
  ✓ lib_a/core_types.mli
    Fixed 3 errors
  
    Iteration 2:
  Removing 2 unused exports...
  ✓ lib_a/core_types.mli
    Fixed 2 errors
  
    Iteration 3:
  ✓ No more unused code found
  
  Summary: removed 5 exports and 5 implementations in 2 iterations (19 lines total)

Verify cascading cleanup worked:

  $ dune build

  $ dune exec ./bin/main.exe
  ID: 42, Name: test
  Service: processed-42

Check what remains in each library:

  $ cat lib_a/core_types.mli
  (** Shared types used by multiple libraries. *)
  
  type id = int
  type name = string
  
  val make_id : int -> id
  val make_name : string -> name
  
  
  
  
  
  (** Used by lib_b's used code *)
  val id_to_int : id -> int
  
  
  

  $ cat lib_b/service.mli
  (** Service layer using core_types. *)
  
  val process : Core_types.id -> string
  
  
