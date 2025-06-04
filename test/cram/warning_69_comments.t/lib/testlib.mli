type person = {
  (** Person's name *)
  name : string;
  (** Person's age - unused *)  
  age : int;
  (* Internal ID - unused *)
  id : int;
}

val make_person : string -> person
val make_simple : string -> person  
val get_name : person -> string