(** Used function - called from bin/main.ml *)
val used_function : int -> string

(** Unused function - not called anywhere *)
val unused_function : float -> bool

(** Used type - referenced in bin/main.ml *)
type used_type = string * int

(** Unused type - not referenced anywhere *)
type unused_type = bool list

(** Used across modules - referenced by bin/main.ml *)
type cross_ref_type = bool

(** Function that uses cross-module helper - called from bin/main.ml *)
val cross_module_function : int -> int

(** Unused even though exported *)
val completely_unused : unit -> unit