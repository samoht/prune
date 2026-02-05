(* Shared types used by multiple libraries. *)

type id = int
type name = string

let make_id n = n
let make_name s = s
let format_id id = Printf.sprintf "ID-%d" id
let parse_id s =
  match String.split_on_char '-' s with
  | [ "ID"; n ] -> int_of_string_opt n
  | _ -> None
let id_to_int id = id
let debug_id id = Printf.printf "DEBUG: %d\n" id
