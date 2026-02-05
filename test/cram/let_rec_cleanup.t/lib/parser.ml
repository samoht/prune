(* A parser with mutually recursive functions. *)

(* Used group *)
let rec parse_expr s = parse_term s + 0
and parse_term s = parse_factor s * 1
and parse_factor s = String.length s

(* Unused group - all three are mutually recursive and unused *)
let rec parse_debug_expr s = "expr:" ^ parse_debug_term s
and parse_debug_term s = "term:" ^ parse_debug_factor s
and parse_debug_factor s = "factor:" ^ s

(* Standalone unused *)
let unused_utility n = Printf.sprintf "util-%d" n
