(** A parser with mutually recursive functions. *)

(** Used mutual recursion group *)
val parse_expr : string -> int
val parse_term : string -> int
val parse_factor : string -> int

(** Unused mutual recursion group *)
val parse_debug_expr : string -> string
val parse_debug_term : string -> string
val parse_debug_factor : string -> string

(** Standalone unused *)
val unused_utility : int -> string
