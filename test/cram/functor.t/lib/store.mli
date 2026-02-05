(** Functor-based key-value store. *)

module type KEY = sig
  type t
  val compare : t -> t -> int
  val to_string : t -> string
end

module type S = sig
  type key
  type 'a t
  val empty : 'a t
  val add : key -> 'a -> 'a t -> 'a t
  val find_opt : key -> 'a t -> 'a option
  val size : 'a t -> int
  val debug_dump : 'a t -> string
end

module Make (K : KEY) : S with type key = K.t
