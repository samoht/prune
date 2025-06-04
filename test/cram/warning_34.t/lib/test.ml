type used_type = int
type unused_type = string
type internal_type = float  (* This will trigger Warning 34 *)

let make_used x : used_type = x