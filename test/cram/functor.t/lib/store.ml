(* Functor-based key-value store. *)

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

module Make (K : KEY) : S with type key = K.t = struct
  type key = K.t
  type 'a t = (key * 'a) list
  let empty = []
  let add k v t = (k, v) :: t
  let find_opt k t = List.assoc_opt k t
  let size t = List.length t
  let debug_dump t =
    t |> List.map (fun (k, _) -> K.to_string k) |> String.concat ", "
end
