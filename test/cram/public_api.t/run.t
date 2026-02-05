Test --public flag preserves public API exports
================================================

The --public flag marks .mli files as public APIs whose exports should
never be removed, even if they appear unused. This is essential for
library development where the public API must remain stable.

Setup:
- lib/api.mli: public API with used (create, version) and unused (destroy) exports
- lib/internal.mli: internal module with used (helper) and unused (unused_helper, unused_type) exports
- bin/main.ml: uses Api.create, Api.version, Internal.helper

Build and index:
  $ dune build @all @ocaml-index

Test 1: Dry-run without --public shows all unused exports
---------------------------------------------------------

  $ prune clean . --dry-run
  Analyzing 2 .mli files
  lib/api.mli:5:0-25: unused value destroy
  lib/internal.mli:5:0-36: unused value unused_helper
  lib/internal.mli:7:0-16: unused type unused_type
  Found 3 unused exports

Test 2: Dry-run with --public marks api.mli as protected
---------------------------------------------------------

  $ prune clean . --dry-run --public lib/api.mli
  Analyzing 2 .mli files
    Marking 1 file(s) as public APIs (will not be modified):
    - lib/api.mli
  
  lib/internal.mli:5:0-36: unused value unused_helper
  lib/internal.mli:7:0-16: unused type unused_type
  Found 2 unused exports
  
    Unused exports in public files (will not be removed):
  lib/api.mli:5:0-25: unused (public) value destroy

Test 3: Force removal with --public preserves api.mli
------------------------------------------------------

  $ prune clean . -f --public lib/api.mli
  Analyzing 2 .mli files
  
    Marking 1 file(s) as public APIs (will not be modified):
    - lib/api.mli
  
  
    Iteration 1:
  Removing 2 unused exports...
  ✓ lib/internal.mli
    Fixed 2 errors
  
    Iteration 2:
  ✓ No more unused code found
  
  Summary: removed 2 exports and 2 implementations in 1 iteration (4 lines total)

Verify api.mli is unchanged (destroy still present):
  $ grep "destroy" lib/api.mli
  val destroy : int -> unit

Verify internal.mli had unused exports removed:
  $ grep "unused_helper" lib/internal.mli || echo "unused_helper removed (correct)"
  unused_helper removed (correct)

Verify build still works:
  $ dune exec bin/main.exe
  Result: 6, version: 1.0
