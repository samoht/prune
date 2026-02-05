Test handling of very long lines
================================

This test verifies that prune can handle functions with extremely long signatures
that exceed typical line length limits.

Build the project:
  $ dune build

Run prune to check handling of long lines:
  $ prune clean . --dry-run
  Analyzing 1 .mli file
  lib/long_lines.mli:1:0-506: unused value very_long_function_name_that_exceeds_normal_length_expectations_and_continues_for_quite_a_while
  Found 1 unused exports

Test verbose mode shows truncation:
  $ prune clean . --dry-run -v 2>&1 | grep -E "(truncated|very_long)" | head -5
  prune: [INFO] Checking occurrences for very_long_function_name_that_exceeds_normal_length_expectations_and_continues_for_quite_a_while at lib/long_lines.mli:1:0-506 (adjusted to 1:4)
  prune: [INFO] OCCURRENCE MAPPING: very_long_function_name_that_exceeds_normal_length_expectations_and_continues_for_quite_a_while@lib/long_lines.mli:1:0-506 -> 2 occurrences
  lib/long_lines.mli:1:0-506: unused value very_long_function_name_that_exceeds_normal_length_expectations_and_continues_for_quite_a_while
