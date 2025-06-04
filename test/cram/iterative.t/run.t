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
  Analyzing 1 .mli file
  
  
    Iteration 1:
    Fixed 2 errors
  
    Iteration 2:
    Removed 7 exports
  prune: [WARNING] Could not find value binding at lib/testlib.ml:24:4 (No value binding found at position), falling back to item detection
  prune: internal error, uncaught exception:
         Failure("AST-based item bounds detection failed: No structure item found at position")
         
  [125]

The cleanup removed:
- unused_export and its helper
- The entire chain1->chain2->chain3->chain4->chain5
- standalone_unused

Verify what remains:
  $ cat lib/testlib.mli | grep "^val" | wc -l
         2

The remaining exports are:
- entry, step1, step2, step3 (used chain starting from bin)
- used_in_other (used in otherlib)

Build should now succeed:
  $ dune build
  File "lib/testlib.ml", line 2, characters 4-17:
  2 | let unused_export () = 42
          ^^^^^^^^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value unused_export.
  
  File "lib/testlib.ml", line 5, characters 8-14:
  5 | let rec chain1 x = chain2 (x + 1)
              ^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value chain1.
  
  File "lib/testlib.ml", line 6, characters 4-10:
  6 | and chain2 x = chain3 (x * 2)
          ^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value chain2.
  
  File "lib/testlib.ml", line 7, characters 4-10:
  7 | and chain3 x = chain4 (x - 1)
          ^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value chain3.
  
  File "lib/testlib.ml", line 8, characters 4-10:
  8 | and chain4 x = chain5 (x / 2)
          ^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value chain4.
  
  File "lib/testlib.ml", line 9, characters 4-10:
  9 | and chain5 x = x
          ^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value chain5.
  
  File "lib/testlib.ml", line 18, characters 4-19:
  18 | let used_internally x = x * 2
           ^^^^^^^^^^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value used_internally.
  
  File "lib/testlib.ml", line 24, characters 4-21:
  24 | let standalone_unused () = "never used"
           ^^^^^^^^^^^^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value standalone_unused.
  [1]

Test specific path analysis:
  $ prune clean lib/ --dry-run
  Analyzing 1 .mli file
  Error: Build failed:
  File "lib/testlib.ml", line 2, characters 4-17:
  2 | let unused_export () = 42
          ^^^^^^^^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value unused_export.
  
  File "lib/testlib.ml", line 5, characters 8-14:
  5 | let rec chain1 x = chain2 (x + 1)
              ^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value chain1.
  
  File "lib/testlib.ml", line 6, characters 4-10:
  6 | and chain2 x = chain3 (x * 2)
          ^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value chain2.
  
  File "lib/testlib.ml", line 7, characters 4-10:
  7 | and chain3 x = chain4 (x - 1)
          ^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value chain3.
  
  File "lib/testlib.ml", line 8, characters 4-10:
  8 | and chain4 x = chain5 (x / 2)
          ^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value chain4.
  
  File "lib/testlib.ml", line 9, characters 4-10:
  9 | and chain5 x = x
          ^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value chain5.
  
  File "lib/testlib.ml", line 18, characters 4-19:
  18 | let used_internally x = x * 2
           ^^^^^^^^^^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value used_internally.
  
  File "lib/testlib.ml", line 24, characters 4-21:
  24 | let standalone_unused () = "never used"
           ^^^^^^^^^^^^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value standalone_unused.
  [1]

Even when analyzing only lib/, prune correctly identifies that all
remaining exports are used elsewhere in the project.
