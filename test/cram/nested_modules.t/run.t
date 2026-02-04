Test: Nested module handling in prune
=====================================

This test verifies two important behaviors:
1. Prune correctly detects unused exports INSIDE nested modules
2. Modules with used contents are NOT marked as unused
3. Types used by nested modules are correctly preserved

Build the test project:

  $ dune build
  $ dune build @ocaml-index

Check what merlin's outline shows for nested modules:

  $ ocamlmerlin single outline -filename test_lib.mli < test_lib.mli | jq '.value[0].children[] | select(.name == "Level1") | {name, has_children: (.children | length > 0)}'
  {
    "name": "Level1",
    "has_children": true
  }

  $ ocamlmerlin single outline -filename test_lib.mli < test_lib.mli | jq '.value[0].children[] | select(.name == "Level1") | .children[] | select(.kind == "Value") | .name'
  "l1_unused"
  "l1_used"

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

✓ Top module is NOT marked as unused (it has used contents)
✓ top_unused is detected (line 7)
✓ unused_type is detected (line 16)
✓ Level1.l1_unused is detected (line 21) - inside nested module!
✓ Level1.Level2.l2_unused is detected (line 26) - deeply nested!

✓ Level1 module is NOT listed as unused - correctly preserved
✓ Level2 module is NOT listed as unused - correctly preserved  
✓ config type is NOT listed (it's used by make_config)

✓ CompletelyUnused module IS listed (all contents unused)
✓ All contents of CompletelyUnused are listed as unused
✓ AlsoUnused submodule IS listed (all contents unused)

This confirms:
1. ✓ Recursive processing of children in merlin outline works
2. ✓ Module filtering correctly preserves modules with used contents
3. ✓ Modules with all unused contents ARE properly marked for removal

The module filtering now correctly tracks parent-child relationships
in deeply nested structures.

Let's investigate how merlin handles module occurrences:


Check merlin occurrences for module M:

  $ ocamlmerlin single outline -filename test_mod.mli < test_mod.mli | jq '.value[] | select(.name == "M")'
  {
    "start": {
      "line": 1,
      "col": 0
    },
    "end": {
      "line": 1,
      "col": 39
    },
    "name": "M",
    "kind": "Module",
    "type": null,
    "children": [
      {
        "start": {
          "line": 1,
          "col": 15
        },
        "end": {
          "line": 1,
          "col": 35
        },
        "name": "foo",
        "kind": "Value",
        "type": "int -> int",
        "children": [],
        "deprecated": false
      }
    ],
    "deprecated": false
  }

  $ ocamlmerlin single occurrences -identifier-at 1:7 -scope project -filename test_mod.mli < test_mod.mli | jq '. | {count: (.value | length), locations: .value}'
  {
    "count": 0,
    "locations": []
  }

This shows that merlin only finds the module definition and implementation,
NOT the qualified uses like Test_mod.M.foo. This explains why modules are
incorrectly marked as unused - merlin doesn't detect qualified references!

Test: Module with functions used only internally
================================================

This test examines how prune handles modules whose functions are only used
within the same .ml file (not from external modules).

The Store module has functions (get, set, update) that are only used by other
functions in the same file (get_count and increment). Since these functions
are not used externally, prune correctly identifies them as unused exports.

Let's see what prune detects:

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

Note that Store.get, Store.set, and Store.update are marked as unused because
they're only used within the same file, not externally. This is correct behavior
for detecting unused exports.

Let's apply prune's changes:

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

Check what happened to Store module in the .mli:

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

The Store module's functions were removed from the .mli. Now let's see if this
triggers warnings when we build:

  $ dune build 2>&1 | grep -E "warning 32|unused" | head -10

Now run prune again to "fix" these warnings:

  $ prune clean . -f
  Analyzing 2 .mli files
  
  
    Iteration 1:
    ✓ No unused code found

Let's check if the Store module was completely removed:

  $ grep -n "module Store" test_lib.ml || echo "Store module was removed!"
  12:  module Store = struct

Verify the build is now broken:

  $ dune build 2>&1 | grep -E "Error:|Unbound module" | head -3

Expected vs Actual Behavior
===========================

Expected: When prune fixes the unused value warnings, it should only remove the
individual unused functions (get, set, update) from the Store module, preserving
the module structure since it's still referenced by get_count and increment.

Actual: Prune removes the entire Store module structure, causing "Unbound module"
errors because get_count and increment still try to call Store.get().

This is a BUG: The module removal logic should be more conservative and only
remove individual values, not entire module structures when the module is still
being referenced.
