Test module alias with equals sign in .mli files
================================================

This test verifies that prune correctly skips module aliases using
the "module X = Y" syntax in .mli files.

Build and run prune:
  $ dune build
  $ prune clean . --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 3 .mli files
    No unused exports found!

Module aliases A and B are correctly skipped, while unused functions
in the implementation modules are still detected.
