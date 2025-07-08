Test removal of large record types spanning multiple lines

Build the project:
  $ dune build

Check what prune detects as unused:
  $ prune clean . --dry-run
  Analyzing 1 .mli file
  lib/testlib.mli:5:0-26:1: unused type unused_large_record
  lib/testlib.mli:29:0-24: unused type unused_simple
  Found 2 unused exports

Debug: Show what the .mli file looks like before removal:
  $ head -10 lib/testlib.mli
  (** This is a used function *)
  val used_function : int -> int
  
  (** This is an unused large record type that spans many lines *)
  type unused_large_record = {
    field1 : string;
    field2 : int;
    field3 : float;
    field4 : bool;
    field5 : string list;

Test actual removal:
  $ prune clean . --force
  Analyzing 1 .mli file
  
  
    Iteration 1:
    Removed 2 exports
    Fixed 2 errors
  
    Iteration 2:
  ✓ No more unused code found
  
  Summary: removed 2 exports and 2 implementations in 1 iteration (49 lines total)

Debug: Check build after removal:
  $ dune build 2>&1 || echo "Build failed with exit code $?"
Verify the large record type was completely removed:
  $ cat lib/testlib.mli
  (** This is a used function *)
  val used_function : int -> int
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  type used_type = string

This shows proper iterative behavior: exports are removed from .mli files first,
then orphaned implementations are cleaned up in subsequent iterations.

Verify the file still compiles:
  $ dune build
  $ dune exec ./main.exe
  Result: 43
