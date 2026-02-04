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
  ocamlmerlin: command not found

  $ ocamlmerlin single outline -filename test_lib.mli < test_lib.mli | jq '.value[0].children[] | select(.name == "Level1") | .children[] | select(.kind == "Value") | .name'
  ocamlmerlin: command not found

Run prune to detect unused exports:

  $ prune clean . --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 2 .mli files
    No unused exports found!

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
  ocamlmerlin: command not found

  $ ocamlmerlin single occurrences -identifier-at 1:7 -scope project -filename test_mod.mli < test_mod.mli | jq '. | {count: (.value | length), locations: .value}'
  ocamlmerlin: command not found

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
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 2 .mli files
    No unused exports found!

Note that Store.get, Store.set, and Store.update are marked as unused because
they're only used within the same file, not externally. This is correct behavior
for detecting unused exports.

Let's apply prune's changes:

  $ cp test_lib.mli test_lib.mli.bak
  $ cp test_lib.ml test_lib.ml.bak

  $ prune clean . -f
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 2 .mli files
  
  
    Iteration 1:
    ✓ No unused code found

Check what happened to Store module in the .mli:

  $ diff -u test_lib.mli.bak test_lib.mli | grep -A3 -B3 "Store\|get\|set\|update" || true

The Store module's functions were removed from the .mli. Now let's see if this
triggers warnings when we build:

  $ dune build 2>&1 | grep -E "warning 32|unused" | head -10

Now run prune again to "fix" these warnings:

  $ prune clean . -f
  prune: [WARNING] ocamlmerlin not found in PATH
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
