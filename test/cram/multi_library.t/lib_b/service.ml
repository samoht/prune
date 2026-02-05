(* Service layer using core_types. *)

let process id =
  Printf.sprintf "processed-%d" (Core_types.id_to_int id)

let unused_format id =
  Core_types.format_id id

let unused_parse_and_format s =
  match Core_types.parse_id s with
  | Some id -> Some (Core_types.format_id id)
  | None -> None
