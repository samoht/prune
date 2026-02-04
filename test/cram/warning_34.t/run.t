Test Warning 34 (unused type declarations)
==========================================

This test verifies prune's support for OCaml Warning 34, which detects unused type
declarations in .ml files. Prune can identify and fix these warnings during iteration.

Current file contents show internal_type that will trigger Warning 34:
  $ cat lib/test.ml
  type used_type = int
  type unused_type = string
  type internal_type = float  (* This will trigger Warning 34 *)
  
  let make_used x : used_type = x

Build shows Warning 34:
  $ dune build 2>&1 | grep -E "warning 34" || echo "Build failed"
  Error (warning 34 [unused-type-declaration]): unused type internal_type.

Run prune - it detects the build failure due to Warning 34:
  $ prune clean . --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
  Error: Build failed:
  File "lib/test.ml", line 3, characters 0-26:
  3 | type internal_type = float  (* This will trigger Warning 34 *)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^
  Error (warning 34 [unused-type-declaration]): unused type internal_type.
  [1]

Run prune with --force to see it fix Warning 34 in the first iteration:
  $ prune clean . --force -vv 2>&1 | grep -E "(Iteration|Fixed|Removed|internal_type)" | head -10
    Iteration 1:
  prune: [DEBUG] Found warning 'internal_type' type Unused_type on line 3: Error (warning 34 [unused-type-declaration]): unused type internal_type.
  prune: [DEBUG]   lib/test.ml:3:0-26: Unused_type internal_type
  prune: [DEBUG] Found warning 'internal_type' type Unused_type on line 3: Error (warning 34 [unused-type-declaration]): unused type internal_type.
  prune: [DEBUG]   lib/test.ml:3:0-26: Unused_type internal_type
  3 | type internal_type = float  (* This will trigger Warning 34 *)
  Error (warning 34 [unused-type-declaration]): unused type internal_type.
  prune: [DEBUG] Using original location for internal_type: 3-3
  prune: [DEBUG] Applying line removal for internal_type: 1 lines marked
  prune: [DEBUG] replace_line lib/test.ml:3 'type internal_type = float  (* This will trigger Warning 34 *)' -> ''

This demonstrates that prune:
1. Detects Warning 34 errors in the build output
2. Correctly parses the warning to identify the unused type
3. Removes the unused type declaration from the .ml file
4. Continues with further iterations to clean up any other unused code
