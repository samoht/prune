# Prune Test Suite

The test suite is organized into unit tests and integration tests to ensure comprehensive coverage.

## Test Organization

### Unit Tests (test_*.ml)

These files contain unit tests that test individual functions in isolation:

- **test_removal.ml**: Tests the removal module's algorithms
  - `parse_warnings_output`: Tests parsing of compiler warning messages
  - `apply_line_removal_marks`: Tests the line removal algorithm
  - `compute_lines_to_remove`: Tests the line merging algorithm with controlled inputs
  - `find_doc_comment_start`: Tests documentation comment detection
  - Uses controlled/mock `mark_lines_fn` to test algorithms independently of merlin

- **test_warning_parse.ml**: Tests warning parsing functionality
  - Tests both old and new warning formats
  - Tests warning 32 (unused values) and 34 (unused types) parsing

- **test_nested_modules.ml**: Tests module structure preservation
  - Uses controlled `mark_lines_fn` to test the content transformation
  - Verifies that module structure is preserved during removal

### Integration Tests (test_integration.ml)

These tests use real merlin functionality and temporary files:

- **mark_lines_for_removal**: Tests with actual merlin calls
  - Creates temporary OCaml projects
  - Tests both value and type removal with real merlin responses
  
- **remove_unused_exports**: End-to-end test of the removal process
  - Creates real .mli and .ml files
  - Verifies that unused items are removed and used items remain

### Cram Tests (*.t/)

Located in subdirectories, these test the CLI tool's behavior:
- Test the complete prune workflow
- Verify command-line interface and output
- Check iterative cleanup functionality

## Test Design Principles

1. **Unit tests** use controlled inputs to test algorithms in isolation
2. **Integration tests** use real dependencies (merlin) to test actual behavior
3. **Cram tests** verify the end-user experience

This separation ensures both:
- Fast, predictable unit tests for algorithm correctness
- Comprehensive integration tests for real-world behavior