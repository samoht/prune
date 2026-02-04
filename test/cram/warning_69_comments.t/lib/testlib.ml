type person = {
  (** Person's name *)
  name : string;
  (** Person's age - unused *)
  age : int;
  (* Internal ID - unused *)
  id : int;
}

let make_person name = { name; age = 0; id = 0 }

(* Another constructor that doesn't use all fields *)
let make_simple name = { name; age = 25; id = 1 }

let get_name p = p.name