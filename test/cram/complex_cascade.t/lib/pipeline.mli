(** A data processing pipeline with deep dependency chains. *)

(** Entry point - used by main *)
val run : int -> int

(** Stage 1 - used by run *)
val transform : int -> int

(** Unused entry point that triggers a chain of unused internal helpers *)
val unused_entry : float -> float

(** These are only used by unused_entry, forming a long chain *)
val normalize : float -> float
val scale : float -> float -> float
val clamp : float -> float -> float -> float
val validate_range : float -> float -> float -> bool
val format_result : float -> string
