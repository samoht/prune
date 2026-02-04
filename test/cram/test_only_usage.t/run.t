Test detection of functions used only in excluded directories
============================================================

This test verifies that prune correctly identifies functions that are
only used in excluded directories (e.g., test directories).

Build the project:
  $ dune build

Run prune without --exclude:
  $ prune clean . --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
    No unused exports found!

Run prune with --exclude test (excluding the test directory):
  $ prune clean . --dry-run --exclude test
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
    No unused exports found!

The output correctly shows:
- completely_unused: truly unused (not used anywhere)  
- test_helper: only used in test/test_mylib.ml (excluded directory)
- create_test_data: only used in test/test_mylib.ml (excluded directory)
- Other functions are used in bin/main.ml which is NOT excluded

Test that symbols are correctly classified when excluding directories.
The key insight is that functions used in both excluded and non-excluded
directories are still considered "used", not "used only in excluded dirs".
