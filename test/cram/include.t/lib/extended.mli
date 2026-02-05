(** Extended module - includes Base and adds more functionality *)

include module type of Base

val ext_used : int -> string

val ext_unused : float -> float
