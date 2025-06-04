Test analyzing specific directories

Build the project:

  $ dune build @ocaml-index

Test analyzing the entire project:

  $ prune clean . --dry-run
  Analyzing 3 .mli files
  lib1/module1.mli:2:0-35: unused value unused_function
  lib2/module2.mli:2:0-31: unused value another_unused
  lib3/module3.mli:1:0-31: unused value not_analyzed
  lib3/module3.mli:2:0-36: unused value also_not_analyzed
  Found 4 unused exports

Test analyzing only lib1 directory:

  $ prune clean lib1 --dry-run
  Analyzing 1 .mli file
  lib1/module1.mli:2:0-35: unused value unused_function
  Found 1 unused exports

Test analyzing only lib2 directory:

  $ prune clean lib2 --dry-run
  Analyzing 1 .mli file
  lib2/module2.mli:2:0-31: unused value another_unused
  Found 1 unused exports

Test analyzing multiple directories (lib1 and lib2, excluding lib3):

  $ prune clean lib1 lib2 --dry-run
  Analyzing 2 .mli files
  lib1/module1.mli:2:0-35: unused value unused_function
  lib2/module2.mli:2:0-31: unused value another_unused
  Found 2 unused exports

Note: lib3 exports (not_analyzed, also_not_analyzed) are NOT in the output

Test mixing files and directories:

  $ prune clean lib1 lib2/module2.mli --dry-run
  Analyzing 2 .mli files
  lib1/module1.mli:2:0-35: unused value unused_function
  lib2/module2.mli:2:0-31: unused value another_unused
  Found 2 unused exports

Test with non-existent directory:

  $ prune clean nonexistent_dir --dry-run
  Error: nonexistent_dir: No such file or directory
  [1]

Test iterative mode with specific paths:

  $ prune clean lib1 lib2 --force
  Analyzing 2 .mli files
  
  
    Iteration 1:
    Removed 2 exports
    Fixed 2 errors
  
    Iteration 2:
  ✓ No more unused code found
  
  Summary: removed 2 exports and 2 implementations in 1 iteration (4 lines total)
