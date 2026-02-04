open Printf  (* Warning 33 *)
open List    (* Used *)

type used_type = int
type unused_type = string  (* Warning 34 *)

let used_fun x = map (fun y -> y + 1) x
let unused_fun x = x + 1   (* Warning 32 *)

let internal_only () = print_endline "internal"