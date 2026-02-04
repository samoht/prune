Test analyzing specific directories

Build the project:

  $ dune build @ocaml-index

Test analyzing the entire project:

  $ prune clean . --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 3 .mli files
    No unused exports found!

Test analyzing only lib1 directory:

  $ prune clean lib1 --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
    No unused exports found!

Test analyzing only lib2 directory:

  $ prune clean lib2 --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
    No unused exports found!

Test analyzing multiple directories (lib1 and lib2, excluding lib3):

  $ prune clean lib1 lib2 --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 2 .mli files
    No unused exports found!

Note: lib3 exports (not_analyzed, also_not_analyzed) are NOT in the output

Test mixing files and directories:

  $ prune clean lib1 lib2/module2.mli --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 2 .mli files
    No unused exports found!

Test with non-existent directory:

  $ prune clean nonexistent_dir --dry-run
  Error: nonexistent_dir: No such file or directory
  [1]

Test iterative mode with specific paths:

  $ prune clean lib1 lib2 --force
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 2 .mli files
  
  
    Iteration 1:
    ✓ No unused code found
