Basic functionality test
========================

This test verifies that prune correctly detects and removes unused exports.

Build the project first:
  $ dune build

Run prune with --dry-run to see what would be removed:
  $ prune clean . --dry-run
  Analyzing 1 .mli file
  lib/test_lib.mli:5:0-35: unused value unused_value
  lib/test_lib.mli:11:0-24: unused type unused_type
  Found 2 unused exports

Files should not be modified with --dry-run:
  $ wc -l < lib/test_lib.mli
        22

Run prune without arguments (iterative cleanup with prompt):
  $ prune clean .
  Analyzing 1 .mli file
  
  
    Iteration 1:
  
  Found 2 unused exports:
  lib/test_lib.mli:5:0-35: unused value unused_value
  lib/test_lib.mli:11:0-24: unused type unused_type
  Found 2 unused exports
  Remove unused exports? [y/N]: n (not a tty)
  Cancelled - no changes made




Files should remain unchanged (no confirmation given):
  $ wc -l < lib/test_lib.mli
        22

Run prune with -f for automatic removal:
  $ prune clean . -f
  Analyzing 1 .mli file
  
  
    Iteration 1:
  Removing 2 unused exports...
  ✓ lib/test_lib.mli
    Fixed 2 errors
  
    Iteration 2:
  ✓ No more unused code found
  
  Summary: removed 2 exports and 2 implementations in 1 iteration (6 lines total)





Verify unused items were removed from interface:
  $ cat lib/test_lib.mli
  (** A value that is used by main.ml *)
  val used_value : int -> int
  
  
  
  
  (** A type that is used *)
  type used_type = int
  
  
  
  
  (** An exception that is used *)
  exception Used_error
  
  (** An exception that is never used *)
  exception Unused_error
  
  (** A module alias that is used *)
  module Used_module = String
  
  (** A module alias that is never used *)
  module Unused_module = List












Note that blank lines are left in place of removed items.

The exceptions (Unused_error) and module aliases (Unused_module) are NOT removed
because merlin's occurrence detection is unreliable for modules and exceptions,
so prune conservatively keeps them to avoid breaking code.

Verify unused items were removed from implementation:
  $ cat lib/test_lib.ml
  let used_value x = x * 2
  
  
  
  type used_type = int
  
  
  
  exception Used_error
  
  exception Unused_error
  
  module Used_module = String
  
  module Unused_module = List










The project should still build and run correctly:
  $ dune exec main
  Result: 42
  Caught Used_error
  Length: 5
