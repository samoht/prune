(** A module for testing trailing documentation comment removal *)

val used : int -> int

val unused1 : int -> int
(** This trailing doc comment should be removed with unused1 *)

val unused2 : string -> string
(** This trailing doc comment should be removed with unused2 *)

(** This comment is for a used value, so it stays *)
val also_used : string -> string

val unused3 : float -> float
(** This trailing doc comment should be removed with unused3 *)