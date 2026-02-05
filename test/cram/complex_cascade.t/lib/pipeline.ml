(* A data processing pipeline with deep dependency chains. *)

let transform x = x * 2 + 1

let run x = transform x |> ( + ) 100

(* The chain: unused_entry -> normalize -> scale -> clamp -> validate_range -> format_result *)
let format_result f = Printf.sprintf "%.2f" f

let validate_range lo hi v = v >= lo && v <= hi

let clamp lo hi v =
  if validate_range lo hi v then v
  else if v < lo then lo
  else hi

let scale factor v = v *. factor

let normalize v =
  let scaled = scale 100.0 v in
  let clamped = clamp 0.0 100.0 scaled in
  clamped

let unused_entry v =
  let n = normalize v in
  let _ = format_result n in
  n
