Test analyzing specific .mli files

Build the project:

  $ dune build @ocaml-index

Test analyzing the entire project:

  $ prune clean . --dry-run
  Analyzing 3 .mli files
  lib/first.mli:5:0-35: unused value unused_function
  lib/first.mli:11:0-28: unused type unused_type
  lib/second.mli:5:0-31: unused value another_unused
  lib/second.mli:11:0-33: unused type another_unused_type
  lib/testlib.mli:2:0-32: unused value main_function
  Found 5 unused exports

Test analyzing only the first module:

  $ prune clean lib/first.mli --dry-run
  Analyzing 1 .mli file
  lib/first.mli:5:0-35: unused value unused_function
  lib/first.mli:11:0-28: unused type unused_type
  Found 2 unused exports

Test analyzing only the second module:

  $ prune clean lib/second.mli --dry-run
  Analyzing 1 .mli file
  lib/second.mli:5:0-31: unused value another_unused
  lib/second.mli:11:0-33: unused type another_unused_type
  Found 2 unused exports

Test analyzing both modules specifically:

  $ prune clean lib/first.mli lib/second.mli --dry-run
  Analyzing 2 .mli files
  lib/first.mli:5:0-35: unused value unused_function
  lib/first.mli:11:0-28: unused type unused_type
  lib/second.mli:5:0-31: unused value another_unused
  lib/second.mli:11:0-33: unused type another_unused_type
  Found 4 unused exports

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
  Analyzing 1 .mli file
  lib/testlib.mli:2:0-32: unused value main_function
  Found 1 unused exports

Note: This shows that testlib.mli's main_function is unused, but First and Second 
module references are correctly not listed as unused since they're used in bin/main.ml
