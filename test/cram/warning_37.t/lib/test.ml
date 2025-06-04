(* Implementation with unused constructors *)

type t = A | B | C

(* Only use constructor A *)
let x = A

let process_color = function
  | Red -> "red"
  | Green -> "green"
  | Blue -> "blue"
  | Yellow -> "yellow"
  | Purple -> "purple"

and color =
  | Red
  | Green
  | Blue
  | Yellow  (* This constructor is never created *)
  | Purple  (* This constructor is never created *)

type status =
  | Active
  | Inactive  (* This constructor is never created *)
  | Pending   (* This constructor is never created *)

let get_status () = Active