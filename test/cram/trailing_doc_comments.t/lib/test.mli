(** A module for testing trailing documentation comment removal *)

val used : int -> int

val unused1 : int -> int
(** This trailing doc comment should be removed with unused1 *)

val unused2 : string -> string
(** This is another trailing doc comment
    that spans multiple lines and should be removed *)

(** This comment is for a used value, so it stays *)
val also_used : string -> string

val unused3 : float -> float
(** Yet another trailing comment to be removed *)