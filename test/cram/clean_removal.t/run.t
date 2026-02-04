Directory-based cram test demonstration
=======================================

This test demonstrates how directory-based cram tests are cleaner and easier 
to maintain than inline cat EOF commands. The project files are organized in 
proper directories instead of being created inline.

Build the test project:

  $ dune build --profile=release

Test prune dry-run to see what would be removed:

  $ prune clean --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
    No unused exports found!

Remove the unused exports:

  $ prune clean --force
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
  
  
    Iteration 1:
    ✓ No unused code found

Check if project builds after removal:
  $ dune build 2>&1 || echo "Build failed"
Verify the cleaned .mli file:

  $ cat lib/cleanlib.mli
  (** Function that will be used *)
  val used_function : int -> int
  
  (** Function that will be detected as unused *)
  val unused_function : string -> string
  
  (** Type that will be detected as unused *)
  type unused_type = int * string

Verify the project still works:

  $ dune build --profile=release
  $ dune exec --profile=release bin/main.exe
  Result: 43

Verify no more unused exports:

  $ prune clean --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
    No unused exports found!
