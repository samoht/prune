Warning 32 parsing and error handling test

Build and capture warnings (build fails due to warning 32):
  $ dune build
  File "main.ml", line 1, characters 4-17:
  1 | let unused_helper x = x + 1
          ^^^^^^^^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value unused_helper.
  
  File "main.ml", line 2, characters 4-18:
  2 | let another_unused = "hello"
          ^^^^^^^^^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value another_unused.
  [1]

Test that prune can handle projects with warning 32:
  $ prune clean . --force
  Analyzing 0 .mli files
  
    Iteration 1:
    Fixed 2 errors
  
    Iteration 2:
  ✓ No more unused code found
  
  Summary: removed 0 exports and 2 implementations in 1 iteration (2 lines total)
