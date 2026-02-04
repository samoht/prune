(** Function that will be used *)
val used_function : int -> int

(** Function that will be detected as unused *)
val unused_function : string -> string

(** Type that will be detected as unused *)
type unused_type = int * string