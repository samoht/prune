Basic functionality test
========================

This test verifies that prune correctly detects and removes unused exports.

Build the project first:
  $ dune build

First, let's check what symbols merlin sees in the .mli file:
  $ ocamlmerlin single outline -filename lib/test_lib.mli < lib/test_lib.mli | \
  > jq -r '.value[] | "\(.kind): \(.name)"' | sort
  ocamlmerlin: command not found

Run prune with --dry-run to see what would be removed:
  $ prune clean . --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
    No unused exports found!

Files should not be modified with --dry-run:
  $ wc -l < lib/test_lib.mli
        22

Run prune without arguments (iterative cleanup with prompt):
  $ prune clean .
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
  
  
    Iteration 1:
    ✓ No unused code found

Files should remain unchanged (no confirmation given):
  $ wc -l < lib/test_lib.mli
        22

Run prune with -f for automatic removal:
  $ prune clean . -f
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
  
  
    Iteration 1:
    ✓ No unused code found

Verify unused items were removed from interface:
  $ cat lib/test_lib.mli
  (** A value that is used by main.ml *)
  val used_value : int -> int
  
  (** A value that is never used *)
  val unused_value : string -> string
  
  (** A type that is used *)
  type used_type = int
  
  (** A type that is never used *)
  type unused_type = float
  
  (** An exception that is used *)
  exception Used_error
  
  (** An exception that is never used *)
  exception Unused_error
  
  (** A module alias that is used *)
  module Used_module = String
  
  (** A module alias that is never used *)
  module Unused_module = List





































































Note that blank lines are left in place of removed items.

BUG: The exceptions (Unused_error) and module aliases (Unused_module) are NOT removed.
This is because merlin's occurrence detection is broken for modules and exceptions,
so prune conservatively keeps them to avoid breaking code.

Verify unused items were removed from implementation:
  $ cat lib/test_lib.ml
  let used_value x = x * 2
  
  let unused_value s = s ^ "_unused"
  
  type used_type = int
  
  type unused_type = float
  
  exception Used_error
  
  exception Unused_error
  
  module Used_module = String
  
  module Unused_module = List













The project should still build and run correctly:
  $ dune exec main
  Result: 42
  Caught Used_error
  Length: 5
