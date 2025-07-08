Test empty record cleanup after all fields are removed
======================================================

This test verifies that when all fields are removed from a record type,
the empty record type is replaced with unit to avoid syntax errors.

Build shows warning 69 for both fields:
  $ dune build 2>&1 | grep -A1 "warning 69" | head -4
  Error (warning 69 [unused-field]): record field login_count is never read.
  (However, this field is used to build or mutate values.)
  --
  Error (warning 69 [unused-field]): record field last_login is never read.

Run prune with --force:
  $ prune clean . --force
  Analyzing 0 .mli files
  
    Iteration 1:
    Fixed 4 errors
  
    Iteration 2:
    Fixed 1 error
  
    Iteration 3:
    Fixed 1 error
  
    Iteration 4:
    Fixed 1 error
  
    Iteration 5:
  ✓ No more unused code found
  
  Summary: removed 0 exports and 7 implementations in 4 iterations (7 lines total)

Check what was changed:
  $ cat lib/user.ml
  (* User management module *)
  
  module Internal : sig
    type t
    val create_user : unit -> t
  end = struct
  
  
  
  
  
    type t = unit
  
  
  
  
    let create_user () = ()
  end
