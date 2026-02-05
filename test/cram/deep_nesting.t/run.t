Test deeply nested modules (4 levels) with unused values at each level
======================================================================

This test has Transport > Frame > Header > Flags with unused values
at every nesting level:
- Flags.unused_to_int and Flags.set_debug (level 4)
- Header.unused_header_size (level 3)
- Frame.unused_checksum (level 2)
- Transport.unused_receive (level 1)
- Flags.is_debug (level 4, used only by set_debug which is also unused)

Build fails due to unused values:

  $ dune build

Run prune to clean up all levels:

  $ prune clean . --force
  Analyzing 1 .mli file
  
  
    Iteration 1:
  Removing 10 unused exports...
  ✓ lib/protocol.mli
    Fixed 7 errors
  
    Iteration 2:
  ✓ No more unused code found
  
  Summary: removed 10 exports and 7 implementations in 1 iteration (17 lines total)

Verify the build works and unused items were removed at all levels:

  $ dune build

  $ dune exec ./bin/main.exe
  Sent: v1:hello world
  Urgent: true

Check what remains in the deeply nested Flags module:

  $ grep -A2 "module Flags" lib/protocol.mli | head -10
        module Flags : sig
          type t
          val empty : t
