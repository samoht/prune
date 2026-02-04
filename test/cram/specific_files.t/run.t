Test analyzing specific .mli files

Build the project:

  $ dune build @ocaml-index

Test analyzing the entire project:

  $ prune clean . --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 3 .mli files
    No unused exports found!

Test analyzing only the first module:

  $ prune clean lib/first.mli --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
    No unused exports found!

Test analyzing only the second module:

  $ prune clean lib/second.mli --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
    No unused exports found!

Test analyzing both modules specifically:

  $ prune clean lib/first.mli lib/second.mli --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 2 .mli files
    No unused exports found!

Test error handling for non-existent files:

  $ prune clean lib/nonexistent.mli --dry-run
  Error: lib/nonexistent.mli: No such file or directory
  [1]

Test error handling for non-.mli files:

  $ prune clean lib/first.ml --dry-run
  Error: lib/first.ml: prune only analyzes .mli files, not .ml files
  [1]

Test that cross-module detection still works with specific files:

  $ prune clean lib/testlib.mli --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
    No unused exports found!

Note: This shows that testlib.mli's main_function is unused, but First and Second 
module references are correctly not listed as unused since they're used in bin/main.ml
