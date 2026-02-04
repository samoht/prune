Test cross-module detection capabilities
========================================

This test verifies that prune correctly detects usage across module boundaries.

Build the project and index:

  $ dune build @ocaml-index

Test that the project runs:

  $ dune exec ./bin/main.exe
  Result: 42, Data: hello, Flag: 42, Cross: 11

Now test cross-module detection with prune:

  $ prune clean . --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 2 .mli files
    No unused exports found!

The test correctly identifies:
- unused_function, unused_type, completely_unused in testlib.mli
- unused_helper, unused_cross_function in other_module.mli

And correctly keeps:
- used_function, used_type, cross_ref_type, cross_module_function (used in main.ml)
- helper_function (used by testlib.ml through cross_module_function)
