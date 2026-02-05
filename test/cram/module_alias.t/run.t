Test that module aliases are preserved
======================================

Module aliases are commonly used for:
1. API compatibility when renaming modules
2. Shorthand names for commonly used modules
3. Re-exporting modules from other packages

Test 1: Module alias used for API compatibility
------------------------------------------------

Build and run prune:
  $ dune build
  $ prune clean . --dry-run
  Analyzing 4 .mli files
  lib/internal.mli:2:0-33: unused value make_array
  lib/original.mli:1:0-24: unused value compute
  Found 2 unused exports

Module aliases (mylib.mli) are correctly not reported as unused.
Values inside module type signatures (sigs.mli) are also correctly
not reported since they are part of the type definition.
Only genuinely unused values (make_array, compute) are detected.

Test 2: Module type aliases
----------------------------

  $ prune clean . --dry-run 2>&1 | grep "unused" | grep "module type" || echo "Module type aliases not detected as unused (correct)"
  Module type aliases not detected as unused (correct)

Module type aliases are correctly not marked as unused.

Expected behavior: Module aliases (both module and module type) should never
be marked as unused, as they serve important purposes for API design and
compatibility.
