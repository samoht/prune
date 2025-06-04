# Debugging Guide for prune

This document contains tips and tricks for debugging issues with merlin and the prune tool.

## Merlin Debugging Tips

### 1. Ensuring the Correct ocamlmerlin Binary

When using merlin server mode (now the default), it's crucial to ensure you're using the correct `ocamlmerlin` binary that matches your project's OCaml version. The merlin server persists across commands, so using the wrong binary can lead to confusing errors.

```bash
# Check which ocamlmerlin is in your PATH
which ocamlmerlin

# If using opam, ensure you're in the right switch
opam switch
eval $(opam env)

# The tool will use whatever ocamlmerlin is in your PATH
# To use a specific binary, adjust your PATH before running prune:
export PATH="/path/to/correct/ocaml/bin:$PATH"
prune --dry-run
```

### 2. Testing Merlin Commands Manually

When debugging merlin issues, always use the correct working directory and file paths:

```bash
# WRONG - this won't work from parent directory
cd .. && ocamlmerlin server outline -filename subdir/file.mli < subdir/file.mli

# CORRECT - run from the project root where dune-project is located
ocamlmerlin server outline -filename lib/file.mli < lib/file.mli
```

### 3. Understanding Merlin's JSON Output

Use `jq` to parse and explore merlin's JSON responses:

```bash
# Get full outline
ocamlmerlin server outline -filename lib/test.mli < lib/test.mli | jq

# Get specific symbol info
ocamlmerlin server outline -filename lib/test.mli < lib/test.mli | jq '.value[] | select(.name == "symbol_name")'

# Check occurrences with exact position
ocamlmerlin server occurrences -identifier-at LINE:COL -scope project -filename lib/test.mli < lib/test.mli | jq
```

### 4. Common Column Position Issues

Merlin uses 0-based column positions. The outline command returns the exact start position of each symbol:

- For `type t = ...`, the position points to the 't' in 'type'
- For `val f : ...`, the position points to the 'v' in 'val'

When checking occurrences, you need to use the exact position of the identifier name, not the keyword:

```ocaml
type used_type = int
     ^
     col 5 (this is where "used_type" starts)

val used_value : int -> int  
    ^
    col 4 (this is where "used_value" starts)
```

### 5. Cross-Module Occurrence Detection

**Important**: Merlin's occurrence detection works well from `.mli` files when using the correct location:

- Use the exact line and column position from the `outline` command
- Always ensure the project is built with `dune build @ocaml-index` before testing
- The index must be up-to-date for cross-module detection to work

### 6. Debug Workflow

1. Create a minimal test case:
   ```bash
   mkdir test_case
   cd test_case
   # Create dune-project, .opam file, and test files
   ```

2. Build the project and index:
   ```bash
   dune build @install
   dune build @ocaml-index
   ```

3. Test merlin commands directly:
   ```bash
   # Check outline
   ocamlmerlin server outline -filename lib/test.mli < lib/test.mli | jq
   
   # Check occurrences (use exact column from outline)
   ocamlmerlin server occurrences -identifier-at 1:5 -scope project -filename lib/test.mli < lib/test.mli | jq
   
   # Stop the server when done debugging
   ocamlmerlin server stop-server
   ```

4. Compare with tool output:
   ```bash
   prune -vv  # Use verbose mode to see merlin commands
   ```

### 7. Known Limitations

- Module type occurrences may not be tracked properly
- Functors and first-class modules have limited support
- Module aliases (e.g., `module M = N`) can cause false positives:
  - Merlin may not track occurrences through module aliases correctly
  - Values used through aliases like `Alias.Module.value` may be marked as unused
  - This is a merlin limitation that affects occurrence tracking