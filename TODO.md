# TODO List for prune

This file tracks ongoing tasks and issues for the prune project.

## Code Quality

- [ ] **Move module_alias detection to use AST (in locate) instead of regex**
    The module_alias.ml file uses complex regex patterns to detect module aliases.
    This should be done on the AST in the locate module for better accuracy and maintainability.

- [ ] **Move occurrence.ml string parsing to use AST (in locate) instead**
    The occurrence.ml file does string manipulation to find identifier positions
    (e.g., find_type_identifier_column, get_identifier_column). This should use
    the AST via the locate module for better accuracy.

- [ ] **Improve Cache Performance**
    - **File(s):** `lib/cache.ml`, `lib/cache.mli`, `lib/analysis.ml`
    - **Description:** The current implementation of `get_cached_file_content` in `lib/analysis.ml` reads a file from the cache line-by-line, prepending to a list and then concatenating. This is inefficient for large files.
    - **Precise Scope:**
        1.  **`lib/cache.mli`**: Add a new function signature `val get_file_content : t -> string -> string option`. This function will be responsible for returning the entire content of a cached file as a single string.
        2.  **`lib/cache.ml`**: Implement `get_file_content`. The implementation will look up the `file_entry` and, if found, use `String.concat "\n" (Array.to_list entry.lines)` to efficiently construct the full string content from the cached line array.
        3.  **`lib/analysis.ml`**: Remove the local `get_cached_file_content` helper function. Modify the `outline_item_to_symbol` function to call the new `Cache.get_file_content` function directly. This centralizes the logic and improves performance.

- [ ] **Simplify Symbol Analysis**
    - **File(s):** `lib/analysis.ml`
    - **Description:** The `find_multi_mli_symbols` function uses an imperative `Hashtbl` to identify symbols defined in multiple `.mli` files. This can be rewritten using a more declarative, functional style which is generally safer and easier to reason about in OCaml.
    - **Precise Scope:**
        1.  Refactor the `find_multi_mli_symbols` function.
        2.  Instead of a `Hashtbl`, use `List.fold_left` to build a `String.Map.t`. The map's keys will be symbol names, and the values will be a list of unique file paths where the symbol is defined.
        3.  Use `String.Map.filter` to select only the symbols where the list of file paths has a length greater than one.
        4.  Extract the names from the filtered map into a list. This eliminates mutation and makes the data flow more explicit.

- [ ] **Refactor AST Traversal**
    - **File(s):** `lib/locate.ml`
    - **Description:** Several functions in this module perform redundant list-to-array conversions for iteration and contain verbose logic for checking location boundaries.
    - **Precise Scope:**
        1.  In `find_field_in_type` and `find_field_in_record`, remove the `Array.of_list` and `Array.find_mapi` calls. Replace them with `List.find_map` to iterate over the list of declarations directly, avoiding the intermediate array allocation.
        2.  In `get_enclosing_record`, the logic to check if one location is inside another is verbose and repeated. Create a new helper function, `is_loc1_contained_in_loc2`, that encapsulates this boundary-checking logic. Use this helper within the AST visitor to simplify the code.

- [ ] **Clarify Code Removal Logic**
    - **File(s):** `lib/removal.ml`
    - **Description:** The `process_field_removals` function has a complex, nested control flow for deciding how to remove record fields, especially when an entire record becomes empty.
    - **Precise Scope:**
        1.  Flatten the logic within `process_field_removals`.
        2.  After grouping field removal operations by the enclosing record, determine if all fields of a record are being removed.
        3.  Use a single `match` statement on a tuple `(is_last_field, field_context)` where `is_last_field` is a boolean and `field_context` is either `` `Type_definition` `` or `` `Record_construction` ``.
        4.  The match cases will directly call the appropriate function: `replace_type_with_unit`, `replace_record_with_unit`, or process the field individually. This will make the decision tree much clearer.

- [ ] **Optimize Comment Scanning**
    - **File(s):** `lib/comments.ml`
    - **Description:** The functions for finding preceding and trailing comments (`find_preceding_comment_start`, `find_trailing_comment_end`) involve multiple, sometimes nested, recursive scans, which can be inefficient and hard to follow.
    - **Precise Scope:**
        1.  Refactor `find_preceding_comment_start` to use a single, stateful loop that scans backwards from the target line.
        2.  This loop will maintain the current comment nesting depth (for `(* ... *)` blocks) and a state (e.g., `Scanning`, `InComment`).
        3.  The scan will continue until it encounters a line of code outside of any comment block, at which point it stops. This avoids the overhead of multiple function calls and simplifies the control flow into a single pass.
        4.  Apply a similar single-pass simplification to `find_trailing_comment_end`.

## Bugs Found in Cram Tests




## Later

- [ ] **Debug and fix merlin server mode - tests fail when using --server**
    Server mode invocation seems to have different behavior than single mode
