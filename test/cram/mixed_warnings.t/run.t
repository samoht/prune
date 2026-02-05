Test mixed warning types (w32 + w37 + w69)
==========================================

This test combines three warning types in one project:
- Warning 32: unused_helper and unused_log_parser are never called
- Warning 37: Debug, Critical, Trace, Verbose constructors are never used
- Warning 69: debug_trace, max_retries fields are never read

Prune must handle all three simultaneously across multiple iterations.

Build fails due to multiple warning types:

  $ dune build

Run prune to fix all warnings iteratively:

  $ prune clean . --force
  Analyzing 1 .mli file
  
  
    Iteration 1:
  Removing 2 unused exports...
  ✓ lib/config.mli
    Fixed 2 errors
  
    Iteration 2:
  ✓ No more unused code found
  
  Summary: removed 2 exports and 2 implementations in 1 iteration (9 lines total)

Verify build succeeds and program still works:

  $ dune build

  $ dune exec ./bin/main.exe
  Connection: example.com:443 (timeout=30.0)
  Level: INFO
  Default host: localhost
  Default port: 8080
    INFO
    WARNING
    ERROR
