(** This module tests comprehensive documentation comment removal *)

(* Regular comment before used function *)
(** This function is actually used *)
val used : unit -> unit

(* Regular comment that should stay *)

(** Leading doc comment for unused function *)
val unused_leading : unit -> int

val unused_trailing : int -> int
(** Trailing doc comment that should be removed *)

(** Leading multi-line doc comment
    with several lines of documentation
    that should all be removed *)
val unused_mixed : string -> string
(** Also has a trailing comment *)

(** Complex documentation
    @param () unit parameter
    @return string value
    @since 1.0.0 *)
val unused_multiline : unit -> string
(** Post-doc: implementation details *)
(* Regular comment after *)

(** Documentation for a used function *)
val used_with_docs : int -> int
(* This comment stays too *)

(* Final regular comment *)