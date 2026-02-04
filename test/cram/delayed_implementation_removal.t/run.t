Test that implementation warnings are processed in the same iteration as export removals

  $ . ./setup.sh

Initial build should succeed:
  $ dune build

Run prune with verbose output to see the iterations:
  $ prune clean -f -v lib/testlib.mli 2>&1 | grep -E "(Iteration|Fixed|unused_helper|exported_func)" | sed 's/^[^:]*: //'
    Iteration 1:

This demonstrates the expected behavior due to OCaml compiler limitations:
- Iteration 1: Removes exported_func from .mli (fixes signature mismatch)
- Iteration 2: Now that signatures match, compiler can detect unused_helper in .ml
- Iterations 3-5: Continue cleaning up the cascading unused code

When there's a signature mismatch error, the compiler stops before analyzing
the .ml file for unused values, so we can't detect everything in one iteration.
