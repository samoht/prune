(** Module using a named module type with include *)

module type S = sig
  val common : int -> int
end

module Sub : sig
  include S
  val sub_used : string -> int
  val sub_unused : int -> int
end

val top_used : int -> int

val top_unused : string -> string
