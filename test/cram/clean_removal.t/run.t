Directory-based cram test demonstration
=======================================

This test demonstrates how directory-based cram tests are cleaner and easier 
to maintain than inline cat EOF commands. The project files are organized in 
proper directories instead of being created inline.

Build the test project:

  $ dune build --profile=release

Test prune dry-run to see what would be removed:

  $ prune clean --dry-run
  Analyzing 1 .mli file
  lib/cleanlib.mli:5:0-38: unused value unused_function
  lib/cleanlib.mli:8:0-31: unused type unused_type
  Found 2 unused exports

Remove the unused exports:

  $ prune clean --force
  Analyzing 1 .mli file
  
  
    Iteration 1:
    Removed 2 exports
    Fixed 2 errors
  
    Iteration 2:
  ✓ No more unused code found
  
  Summary: removed 2 exports and 2 implementations in 1 iteration (6 lines total)

Check if project builds after removal:
  $ dune build 2>&1 || echo "Build failed"
Verify the cleaned .mli file:

  $ cat lib/cleanlib.mli
  (** Function that will be used *)
  val used_function : int -> int
  
  
  
  
  

Verify the project still works:

  $ dune build --profile=release
  $ dune exec --profile=release bin/main.exe
  Result: 43

Verify no more unused exports:

  $ prune clean --dry-run
  Analyzing 1 .mli file
    No unused exports found!
