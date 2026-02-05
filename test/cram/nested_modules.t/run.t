Test: Nested module handling in prune
=====================================

This test verifies three important behaviors:
1. Prune correctly detects unused exports INSIDE nested modules
2. Modules with used contents are NOT marked as unused
3. Types used by nested modules are correctly preserved

Build the test project:

  $ dune build
  $ dune build @ocaml-index

Run prune to detect unused exports:

  $ prune clean . --dry-run
  Analyzing 2 .mli files
  test_lib.mli:7:2-29: unused value top_unused
  test_lib.mli:16:2-24: unused type unused_type
  test_lib.mli:20:4-25: unused value get
  test_lib.mli:21:4-25: unused value set
  test_lib.mli:22:4-37: unused value update
  test_lib.mli:26:2-29: unused value get_count
  test_lib.mli:27:2-30: unused value increment
  test_lib.mli:32:4-32: unused value l1_unused
  test_lib.mli:37:6-34: unused value l2_unused
  test_lib.mli:46:4-28: unused value unused1
  test_lib.mli:47:4-34: unused value unused2
  test_lib.mli:51:6-32: unused value unused3
  test_lib.mli:52:6-27: unused type unused_t
  Found 13 unused exports

Analyze the results:

- Top module is NOT marked as unused (it has used contents)
- top_unused is detected (line 7)
- unused_type is detected (line 16)
- Store.get/set/update detected (lines 20-22) - internal-only usage
- get_count/increment detected (lines 26-27) - internal-only usage
- Level1.l1_unused is detected (line 32) - inside nested module
- Level1.Level2.l2_unused is detected (line 37) - deeply nested
- CompletelyUnused module contents all detected (lines 46-52)

- Level1 module is NOT listed as unused - correctly preserved (has used children)
- Level2 module is NOT listed as unused - correctly preserved
- config type is NOT listed (it's used by make_config)

Apply prune's changes:

  $ cp test_lib.mli test_lib.mli.bak
  $ cp test_lib.ml test_lib.ml.bak

  $ prune clean . -f
  Analyzing 2 .mli files
  
  
    Iteration 1:
  Removing 13 unused exports...
  ✓ test_lib.mli
    Fixed 11 errors
  
    Iteration 2:
    Fixed 2 errors
  
    Iteration 3:
    Fixed 1 error
  
    Iteration 4:
  ✓ No more unused code found
  
  Summary: removed 13 exports and 14 implementations in 3 iterations (30 lines total)







Check that Store module structure is preserved (individual values removed,
module sig kept intact):

  $ diff -u test_lib.mli.bak test_lib.mli | grep -A3 -B3 "Store\|get\|set\|update" || true
  +
  +
     (** Internal store module - functions only used within this module *)
     module Store : sig
  -    val get : unit -> int
  -    val set : int -> unit
  -    val update : (int -> int) -> unit
  +
  +
  +
     end
   
  -  (** Functions that use Store internally *)
  -  val get_count : unit -> int
  -  val increment : unit -> unit
   
  +



Build succeeds after cleanup:

  $ dune build 2>&1 | grep -E "warning 32|unused" | head -10

Run prune again to verify no more unused exports:

  $ prune clean . -f
  Analyzing 2 .mli files
  
  
    Iteration 1:
    ✓ No unused code found



Verify Store module still exists in implementation:

  $ grep -n "module Store" test_lib.ml || echo "Store module was removed!"
  12:  module Store = struct

Build still works:

  $ dune build 2>&1 | grep -E "Error:|Unbound module" | head -3
