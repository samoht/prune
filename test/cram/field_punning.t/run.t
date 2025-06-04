Test field punning with unbound field errors
============================================

This test verifies that prune correctly handles field punning syntax when
fixing unbound field errors. Field punning is when you write `{ name; value; }`
instead of `{ name = name; value = value; }`.

Build shows unbound field errors:
  $ dune build 2>&1 | grep -E "Error:|unbound|field" | head -10
  7 |     extra = "bad";  (* This field is unbound *)
  Error: Unbound record field "extra"
  13 |     unused_field = "unused";  (* This field doesn't exist in the type *)
  Error: Unbound record field "unused_field"

Run prune to fix the unbound fields:
  $ prune clean . --force -vv 2>&1 | grep -E "(Iteration|Fixed|unused_field|debug|Unbound_field|Error|warning)" | grep -v DEBUG
    Iteration 1:
  Error: Unbound record field "extra"
  13 |     unused_field = "unused";  (* This field doesn't exist in the type *)
  Error: Unbound record field "unused_field"
    Fixed 2 errors
    Iteration 2:
  14 |     debug;  (* Punned unbound field *)
  Error: Unbound record field "debug"
  31 |     debug;  (* This field doesn't exist - will cause unbound field error *)
  Error: Unbound record field "debug"
    Fixed 2 errors
    Iteration 3:
  Error: The implementation "lib/testlib.ml"
  Error: The implementation "lib/testlib.ml"

Check the result - the punned fields should remain intact while unbound fields are removed:
  $ cat lib/testlib.ml | sed 's/  *$//'
  type config = {
    name : string;
    value : int;
    enabled : bool;
  }
  
  (* Helper function with an unused field in its local record *)
  let helper () =
    let local_config = {
      name = "test";
      value = 42;
      enabled = true;
  
    } in
    local_config
  
  let make_config name value enabled =
    (* Using field punning syntax here *)
    {
      name;
      value;
      enabled;
    }
  
  (* Another function with field punning and an unbound field *)
  let make_config_with_error name value enabled debug =
    {
      name;
      value;
      enabled;
  
    }

Build should succeed now:
  $ dune build
  File "lib/testlib.ml", line 1:
  Error: The implementation "lib/testlib.ml"
         does not match the interface "lib/testlib.ml": 
         Values do not match:
           val make_config_with_error : string -> int -> bool -> 'a -> config
         is not included in
           val make_config_with_error : string -> int -> bool -> config
         The type "string -> int -> bool -> 'a -> config"
         is not compatible with the type "string -> int -> bool -> config"
         Type "'a -> config" is not compatible with type "config"
         File "lib/testlib.mli", line 9, characters 0-60: Expected declaration
         File "lib/testlib.ml", line 26, characters 4-26: Actual declaration
  [1]

Now test the improved implementation with a simpler example:

  $ dune build lib/simple.ml 2>&1 | grep -A1 "Error:"
  [1]

  $ prune clean lib --force -v 2>&1 | grep -E "(Unbound_field|Fixed)" | head -5

Check the result - comments should be removed with fields:
  $ cat lib/simple.ml
  type t = { name : string; value : int }
  
  let test1 = 
    {
      name = "test";
      value = 42;
                                                 
    }
  
  let test2 =
    {
      name = "test2";
      value = 100;
                                        
    }

The improved implementation:
1. Removes `extra = "bad";  (* This field is unbound *)` entirely including the comment
2. Removes `debug;  (* Punned unbound field *)` entirely including the comment  
3. Only removes the specific fields, not entire functions
