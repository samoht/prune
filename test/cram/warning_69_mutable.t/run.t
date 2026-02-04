Test Warning 69 for mutable fields
===================================

This test verifies prune's support for Warning 69 with mutable fields.

Build shows warning 69:
  $ dune build 2>&1 | grep -A1 "warning 69"
  Error (warning 69 [unused-field]): mutable record field users is never mutated.

Run prune with --force:
  $ prune clean . --force
  Analyzing 0 .mli files
  
    Iteration 1:
    Fixed 1 error
  
    Iteration 2:
  ✓ No more unused code found
  
  Summary: removed 0 exports and 1 implementation in 1 iteration (0 lines total)

Check what was removed:
  $ cat lib/issue.ml
  module Internal : sig 
    type music_library
    val create_library : int list -> music_library  
    val get_users : music_library -> int list
  end = struct
    type music_library = {
      users : int list;
  
    }
  
    let create_library users = { users;             }
  
    let get_users lib = lib.users
  end
