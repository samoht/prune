module type S = sig
  val x : int
end

(* Alias for compatibility *)
module type T = S