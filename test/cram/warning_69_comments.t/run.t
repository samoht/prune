Warning 69 comment removal test
==============================

This test demonstrates the current limitations with warning 69 (unused fields).

Current status:
1. Warning 69 requires special conditions to trigger in OCaml
2. Even when triggered, prune doesn't remove enclosing comments for fields

Build the project:
  $ dune build 2>&1 | grep -E "warning 69" || echo "Build successful"
  Build successful

Check what prune detects (currently no field warnings):
  $ prune clean . --dry-run
  Analyzing 1 .mli file
  lib/testlib.mli:11:0-34: unused value make_simple
  Found 1 unused exports

The unused fields (age, id) are not detected because:
- Warning 69 only triggers when fields are never read AND never used in constructors
- The fields are used in make_person and make_simple constructors

Remove what is detected:
  $ prune clean . --force
  Analyzing 1 .mli file
  
  
    Iteration 1:
    Removed 1 exports
  
    Iteration 2:
  ✓ No more unused code found
  
  Summary: removed 1 export and 0 implementations in 1 iteration (1 line total)

Future improvement needed:
1. Better detection of unused fields (may require compiler changes)
2. When implemented, ensure comments are removed with fields
3. Handle resulting compilation errors from field removal
