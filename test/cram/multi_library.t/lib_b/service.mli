(** Service layer using core_types. *)

val process : Core_types.id -> string
val unused_format : Core_types.id -> string
val unused_parse_and_format : string -> string option
