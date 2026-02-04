Test project without dune-project file
======================================

This test verifies that prune handles projects without a dune-project file.

Note: No dune-project file exists in this test directory.

Try to build (this should fail):
  $ dune build 2>&1 | grep -E "(Error|dune-project)" | head -5
  Warning: No dune-project file has been found in directory ".". A default one
  dune-project file.

Run prune (should handle the missing dune-project gracefully):
  $ prune clean . --dry-run 2>&1 | grep -E "(Error|dune-project|cannot find)" | head -5
  Error: No dune-project file found in $TESTCASE_ROOT
