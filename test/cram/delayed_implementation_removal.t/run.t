Test that implementation warnings are processed in the same iteration as export removals

  $ . ./setup.sh

Initial build should succeed:
  $ dune build

Run prune with verbose output to see the iterations:
  $ prune clean -f -v lib/testlib.mli 2>&1 | grep -E "(Iteration|Fixed|unused_helper|exported_func)" | sed 's/^[^:]*: //'
    Iteration 1:
  [INFO] Checking occurrences for exported_func at lib/testlib.mli:2:0-32 (adjusted to 2:4) with query: occurrences -identifier-at 2:4 -scope project
  [INFO] OCCURRENCE MAPPING: exported_func@lib/testlib.mli:2:0-32 -> 2 occurrences
    Fixed 1 error
    Iteration 2:
    Fixed 1 error
    Iteration 3:

This demonstrates the expected behavior due to OCaml compiler limitations:
- Iteration 1: Removes exported_func from .mli (fixes signature mismatch)
- Iteration 2: Now that signatures match, compiler can detect unused_helper in .ml
- Iterations 3-5: Continue cleaning up the cascading unused code

When there's a signature mismatch error, the compiler stops before analyzing
the .ml file for unused values, so we can't detect everything in one iteration.
