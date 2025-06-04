Test module alias with equals sign in .mli files
================================================

This test verifies that prune correctly skips module aliases using
the "module X = Y" syntax in .mli files.

Build and run prune:
  $ dune build
  $ prune clean . --dry-run
  Analyzing 3 .mli files
  lib/impl_a.mli:2:0-28: unused value unused_func
  lib/impl_b.mli:2:0-37: unused value another_unused
  Found 2 unused exports

Module aliases A and B are correctly skipped, while unused functions
in the implementation modules are still detected.
