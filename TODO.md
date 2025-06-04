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

## Later

- [ ] **Debug and fix merlin server mode - tests fail when using --server**
    Server mode invocation seems to have different behavior than single mode
