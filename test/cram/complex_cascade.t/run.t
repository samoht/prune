Test complex cascading cleanup (5-deep dependency chain)
=========================================================

This test has a deep dependency chain: unused_entry calls normalize,
which calls scale, which calls clamp, which calls validate_range,
which calls format_result. None of these are used externally.

Removing unused_entry should trigger w32 for normalize, then scale,
then clamp, etc. - requiring multiple iterations to fully clean up.

Build fails:

  $ dune build

Run prune iteratively:

  $ prune clean . --force
  Analyzing 1 .mli file
  
  
    Iteration 1:
  Removing 7 unused exports...
  ✓ lib/pipeline.mli
    Fixed 1 error
  
    Iteration 2:
    Fixed 2 errors
  
    Iteration 3:
    Fixed 2 errors
  
    Iteration 4:
    Fixed 1 error
  
    Iteration 5:
  ✓ No more unused code found
  
  Summary: removed 7 exports and 6 implementations in 4 iterations (26 lines total)

Verify only the used functions remain:

  $ dune build

  $ dune exec ./bin/main.exe
  Result: 143

Check what remains in the .mli:

  $ cat lib/pipeline.mli
  (** A data processing pipeline with deep dependency chains. *)
  
  (** Entry point - used by main *)
  val run : int -> int
  
  
  
  
  
  
  
  
  
  
  
  
  
