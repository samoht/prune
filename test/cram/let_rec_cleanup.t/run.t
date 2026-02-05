Test let rec mutual recursion cleanup
=====================================

This test has two mutually recursive function groups:
1. parse_expr/parse_term/parse_factor (used by main)
2. parse_debug_expr/parse_debug_term/parse_debug_factor (unused)

Plus a standalone unused function. Prune must remove the entire
unused recursive group and the standalone function while preserving
the used group.

Build fails:

  $ dune build

Run prune:

  $ prune clean . --force
  Analyzing 1 .mli file
  
  
    Iteration 1:
  Removing 4 unused exports...
  ✓ lib/parser.mli
    Fixed 4 errors
  
    Iteration 2:
  ✓ No more unused code found
  
  Summary: removed 4 exports and 4 implementations in 1 iteration (12 lines total)

Verify the used group still works:

  $ dune build

  $ dune exec ./bin/main.exe
  expr: 5
  term: 5
  factor: 1

Check what remains:

  $ cat lib/parser.mli
  (** A parser with mutually recursive functions. *)
  
  (** Used mutual recursion group *)
  val parse_expr : string -> int
  val parse_term : string -> int
  val parse_factor : string -> int
  
  
  
  
  
  
  
  
