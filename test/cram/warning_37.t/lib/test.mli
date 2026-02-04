(** Test types with constructors *)

type color =
  | Red
  | Green
  | Blue
  | Yellow  (* This constructor is never used *)
  | Purple  (* This constructor is also never used *)

type status =
  | Active
  | Inactive  (* Never used *)
  | Pending

val process_color : color -> string
val get_status : unit -> status