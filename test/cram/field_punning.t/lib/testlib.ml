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
    unused_field = "unused";  (* This field doesn't exist in the type *)
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
    debug;  (* This field doesn't exist - will cause unbound field error *)
  }