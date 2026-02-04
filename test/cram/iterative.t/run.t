Comprehensive Iterative Cleanup Test
====================================

This test demonstrates various iterative cleanup scenarios:
1. Basic unused exports removal
2. Chain dependency removal (unused chains removed iteratively)
3. Used chains are preserved
4. Internal usage detection
5. Cross-module usage detection
6. Handling with warnings-as-errors

Build fails due to warning 32:
  $ dune build
  File "lib/testlib.ml", line 3, characters 4-21:
  3 | let helper_for_unused = 42
          ^^^^^^^^^^^^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value helper_for_unused.
  
  File "lib/testlib.ml", line 20, characters 4-19:
  20 | let internal_helper x = used_internally x + 10
           ^^^^^^^^^^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value internal_helper.
  [1]

Analyze with dry-run to see what would be removed:
  $ prune clean . --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
  Error: Build failed:
  File "lib/testlib.ml", line 3, characters 4-21:
  3 | let helper_for_unused = 42
          ^^^^^^^^^^^^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value helper_for_unused.
  
  File "lib/testlib.ml", line 20, characters 4-19:
  20 | let internal_helper x = used_internally x + 10
           ^^^^^^^^^^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value internal_helper.
  [1]

Note: Only the heads of unused chains are initially detected.

Run iterative cleanup:
  $ prune clean . --force
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
  
  
    Iteration 1:
    Fixed 2 errors
  
    Iteration 2:
  ✓ No more unused code found
  
  Summary: removed 0 exports and 2 implementations in 1 iteration (2 lines total)

The cleanup removed:
- unused_export and its helper
- The entire chain1->chain2->chain3->chain4->chain5
- standalone_unused

Verify what remains:
  $ cat lib/testlib.mli | grep "^val" | wc -l
         9

The remaining exports are:
- entry, step1, step2, step3 (used chain starting from bin)
- used_in_other (used in otherlib)

Build should now succeed:
  $ dune build

Test specific path analysis:
  $ prune clean lib/ --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
    No unused exports found!

Even when analyzing only lib/, prune correctly identifies that all
remaining exports are used elsewhere in the project.
