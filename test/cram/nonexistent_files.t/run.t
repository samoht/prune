Test handling of non-existent files
===================================

Test single non-existent file:
  $ prune clean lib/does_not_exist.mli --dry-run
  Error: lib/does_not_exist.mli: No such file or directory
  [1]

Test multiple non-existent paths:
  $ prune clean path1 path2 path3 --dry-run 2>&1
  Error: path1: No such file or directory
  Error: path2: No such file or directory
  Error: path3: No such file or directory
  [1]

Test mixed existing and non-existing files:
  $ touch exists.mli
  $ prune clean exists.mli does_not_exist.mli --dry-run
  Error: does_not_exist.mli: No such file or directory
  [1]
