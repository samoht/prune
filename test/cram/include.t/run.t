Test include handling in prune
==============================

This test verifies prune handles include statements correctly:
1. Top-level `include module type of X` in .mli files
2. `include S` inside module signatures
3. Directly-defined unused values alongside included ones can be removed
4. Build remains intact after prune runs

Setup:
- lib/base.mli: base module with base_used (used) and base_unused (unused)
- lib/extended.mli: includes base via `include module type of Base`, adds ext_used/ext_unused
- lib/with_sig.mli: named module type S, module Sub with `include S`, top-level values
- bin/main.ml: uses Extended.base_used, Extended.ext_used, With_sig.Sub.sub_used, With_sig.top_used

Build and index:
  $ dune build @all @ocaml-index

Test 1: Dry-run detects unused exports
---------------------------------------

  $ prune clean . --dry-run
  Analyzing 3 .mli files
  lib/base.mli:5:0-34: unused value base_unused
  lib/extended.mli:7:0-31: unused value ext_unused
  lib/with_sig.mli:10:2-29: unused value sub_unused
  lib/with_sig.mli:15:0-33: unused value top_unused
  Found 4 unused exports

Test 2: Force removal preserves include statements
---------------------------------------------------

  $ prune clean . -f
  Analyzing 3 .mli files
  
  
    Iteration 1:
  Removing 4 unused exports...
  ✓ lib/with_sig.mli
  ✓ lib/base.mli
  ✓ lib/extended.mli
    Fixed 4 errors
  
    Iteration 2:
  ✓ No more unused code found
  
  Summary: removed 4 exports and 4 implementations in 1 iteration (8 lines total)

Verify extended.mli still has include statement:
  $ grep "^include" lib/extended.mli
  include module type of Base

Verify build works after cleanup:
  $ dune exec bin/main.exe
  Result: 12
