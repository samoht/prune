Test that module type aliases are preserved
===========================================

Module type aliases (module X : module type of Y) should never be removed,
even if merlin reports no occurrences, as they are important for:
1. API stability
2. Documentation
3. Re-exporting internal modules

Build and check that prune doesn't mark the module type alias as unused:
  $ dune build
  $ prune clean . --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 3 .mli files
    No unused exports found!

The module type alias is correctly preserved even though merlin might not
show it as "used" in the traditional sense.

Test more complex example with multiple module type aliases:
  $ prune clean . --dry-run | grep "module"
  prune: [WARNING] ocamlmerlin not found in PATH
  [1]

All module type aliases are preserved, including:
- Direct aliases: module X : module type of Y
- Single-line include aliases: module X : sig include module type of Y end
- Multi-line include aliases with comments like (** @inline *)
