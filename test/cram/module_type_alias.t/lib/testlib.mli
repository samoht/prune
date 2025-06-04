(** Re-export Internal module for public API *)
module Internal : module type of Internal

(** Direct function that uses Internal *)
val helper : int -> int