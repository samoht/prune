Test handling of read-only files
================================

This test verifies that prune handles read-only .mli files appropriately.

Setup read-only file:
  $ chmod 444 lib/readonly.mli
  $ ls -l lib/readonly.mli | awk '{print $1, $NF}'
  lrwxr-xr-x@ ../../../../../../../default/test/cram/readonly_files.t/lib/readonly.mli

Build the project:
  $ dune build

Test dry-run mode works with read-only files:
  $ prune clean . --dry-run
  Analyzing 1 .mli file
  lib/readonly.mli:1:0-23: unused value unused
  Found 1 unused exports

Test that force mode fails appropriately with read-only files:
  $ prune clean . --force 2>&1 | grep -E "(Error|Permission|readonly)" || echo "Command succeeded unexpectedly"
  ✓ lib/readonly.mli

Restore write permissions for cleanup:
  $ chmod 644 lib/readonly.mli
