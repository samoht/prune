# Cram Test Organization Guidelines

This directory contains all cram tests for the prune project. These tests verify the behavior of prune across different scenarios and warning types.

## Test Organization

Tests are organized by feature or behavior being tested:

- `warning_*.t` - Tests for specific OCaml compiler warnings (32, 33, 34, 69)
- `iterative.t` - Tests for iterative cleanup behavior
- `doc_comments.t` - Tests for documentation comment removal
- `module_*.t` - Tests for module-related functionality
- `*_errors.t` - Tests for error handling scenarios (build failures, infinite loops)
- Feature-specific tests (e.g., `cross_module_detection.t`, `directory_filtering.t`)

### Infinite Loop Detection Tests

Loop detection tests verify that prune properly handles cases where the same build errors repeat across iterations, such as unbound field errors that can't be fixed by replacing with spaces. These tests should:

- Create scenarios that would cause infinite loops (e.g., unbound fields in record construction)
- Verify loop detection messages appear correctly
- Confirm that build output is displayed and exit codes match the build process
- Test both fixable and unfixable error combinations

## Best Practices

### 1. Use Cram Directories, Not Files

✅ **DO**: Create a directory structure:
```
feature_name.t/
├── run.t           # The cram test file
├── dune-project    # Project configuration
├── lib/            # Library code
│   ├── dune
│   ├── test.ml
│   └── test.mli
└── bin/            # Executable code (if needed)
    ├── dune
    └── main.ml
```

❌ **DON'T**: Create a single `feature_name.t` file

### 2. Create Actual Test Files

✅ **DO**: Create real files in the test directory structure

❌ **DON'T**: Use `cat > file << EOF` patterns in cram tests

### 3. Don't Run Commands Directly in Test Directories

✅ **DO**: Add debug commands to `run.t` when debugging:
```bash
# In run.t:
  $ dune build --verbose
  $ ocamlmerlin single dump -what source -filename lib/test.mli < lib/test.mli
```

❌ **DON'T**: Run commands directly in test directories:
```bash
# Don't do this:
$ cd test/cram/warning_32.t && dune build
```

### 4. Debugging Test Failures

When a test is failing and you need to debug it:

1. **Add debug commands to the run.t file**:
   ```bash
   # Original test:
   $ prune . -f --dry-run
   Analyzing 3 .mli files
   ✓ No unused exports found!@.
   
   # Add debug version above it:
   $ prune . -f --dry-run -vv 2>&1 | grep -E "(classify_symbol_usage|re-export|kpi_comparison)" | head -20
   prune.analysis: [DEBUG] classify_symbol_usage: kpi_comparison, count=2
   prune.analysis: [DEBUG] Symbol kpi_comparison appears in multiple .mli files with only 2 occurrences, likely a re-export
   ```

2. **Run the test to see the output**:
   ```bash
   $ dune runtest test/cram/module_alias_signature.t
   ```

3. **The test will fail but show you the actual debug output**, which helps you understand what's happening

4. **Once you understand the issue**, either:
   - Fix the code if it's a bug
   - Update the test expectations if the behavior is correct
   - Remove the debug commands if they're no longer needed

5. **Don't try to guess the output** - just run the test and promote:
   ```bash
   $ dune runtest test/cram/my_test.t
   $ dune promote  # This updates the test with the actual output
   ```

### 5. Naming Conventions

- Name tests after the feature being tested
- Use descriptive names: `warning_32.t`, not `warning32_simple.t`
- Avoid generic suffixes like `_comprehensive`, `_simple`, `_basic`

### 6. Mark Broken Behaviors

Always mark known bugs with `BUG` comments for easy tracking:

```
BUG: prune should continue to iteration 2 and fix the unbound field error.
```

### 7. Test Structure

Each test should:
- Focus on a single feature or warning type
- Include both positive (working) and negative (edge) cases
- Use minimal test projects that demonstrate the specific behavior
- Include descriptive comments explaining what the test verifies
- Show expected vs actual behavior when documenting bugs

## How to Add a New Test

1. **Create the test directory structure**:
   ```bash
   mkdir -p test/cram/my_feature.t/{lib,bin}
   ```

2. **Create the project files**:
   ```bash
   # Create dune-project
   echo "(lang dune 3.0)" > test/cram/my_feature.t/dune-project
   
   # Create library dune file if needed
   cat > test/cram/my_feature.t/lib/dune << 'END'
   (library
    (name test_lib)
    (flags :standard -w +32))
   END
   ```

3. **Create test source files**:
   - Add `.ml` and `.mli` files in `lib/`
   - Add executable files in `bin/` if needed

4. **Write the cram test**:
   ```bash
   cat > test/cram/my_feature.t/run.t << 'END'
   Test description
   ================
   
   This test verifies... [explain what the test does]
   
   Build the project:
     $ dune build
   
   Run prune:
     $ prune . --dry-run
     Analyzing 1 .mli file
     ...
   END
   ```

5. **Run and verify the test**:
   ```bash
   dune test test/cram/my_feature.t
   ```

6. **Promote the test output if correct**:
   ```bash
   dune promote
   ```

## Common Test Patterns

### Testing a Warning

```ocaml
(* In lib/test.ml *)
let unused_fun () = 42  (* This will trigger warning 32 *)

(* In lib/test.mli *)
val unused_fun : unit -> int
```

### Testing Iterative Behavior

Create chains of dependencies to verify multi-iteration cleanup:

```ocaml
let rec chain1 x = chain2 (x + 1)
and chain2 x = chain3 (x * 2)
and chain3 x = x
```

### Testing Cross-Module Dependencies

Use multiple modules to test dependency detection across module boundaries.

## Debugging Tips

1. Add verbose flags to see more details:
   ```
   $ prune . --dry-run -v -v
   ```

2. Enable debug logging for specific cram tests:
   ```
   $ PRUNE_VERBOSE=debug dune build @test/cram/specific_files
   ```
   This shows detailed merlin interactions and helps debug "Invalid outline response" errors.

3. Check merlin's view of the code:
   ```
   $ ocamlmerlin single outline -filename lib/test.mli < lib/test.mli
   ```

4. Verify build errors:
   ```
   $ dune build 2>&1 | grep -E "warning|error"
   ```