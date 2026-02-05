Test Warning 69 (unused record fields)
======================================

This test verifies prune's support for Warning 69 - unused record fields.

Build shows warning 69:
  $ dune build 2>&1 | grep -E "warning 69|unused.*field" | head -2
  5 |     address : string;  (* Warning 69: unused field *)
  Error (warning 69 [unused-field]): record field address is never read.

Run prune with --force:
  $ prune clean . --force
  Analyzing 0 .mli files
  
    Iteration 1:
    Fixed 1 error
  
    Iteration 2:
    Fixed 1 error
  
    Iteration 3:
  ✓ No more unused code found
  
  Summary: removed 0 exports and 2 implementations in 2 iterations (0 lines total)

Check what was removed:
  $ cat lib/fields.ml
  module Internal : sig end = struct
    type person = {
      name : string;
      age : int;
                                                       
    }
    
    let make name age = { name; age;                    }
    let get_name p = p.name
    let get_age p = p.age
    let _ = make, get_name, get_age
  end

Success! The tool now properly removes both the unused field from the type
definition and the corresponding field assignment in the record constructor.
This is achieved by using merlin enclosing to find the exact bounds of the
field = value expression.

Check the field was removed (replaced with spaces):
  $ cat lib/fields.ml | grep -A5 "type person"
    type person = {
      name : string;
      age : int;
                                                       
    }
    
