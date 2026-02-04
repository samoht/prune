Test that build errors are displayed properly (only once)

Run prune - it should show the build error only once:
  $ prune clean . --dry-run 2>&1
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
  Build failed with 1 error - full output:
  File "lib/testlib.ml", line 2, characters 45-45:
  Error: Syntax error
  [1]
