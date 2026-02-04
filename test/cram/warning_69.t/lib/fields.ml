module Internal : sig end = struct
  type person = {
    name : string;
    age : int;
    address : string;  (* Warning 69: unused field *)
  }
  
  let make name age = { name; age; address = "unused" }
  let get_name p = p.name
  let get_age p = p.age
  let _ = make, get_name, get_age
end