(** Shared types used by multiple libraries. *)

type id = int
type name = string

val make_id : int -> id
val make_name : string -> name

(** Only used by unused code in lib_b *)
val format_id : id -> string
val parse_id : string -> id option

(** Used by lib_b's used code *)
val id_to_int : id -> int

(** Not used by anything *)
val debug_id : id -> unit
