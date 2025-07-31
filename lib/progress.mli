(** Progress display utilities for terminal output using the Progress library *)

type t
(** Abstract type for progress state *)

val pp : Format.formatter -> t -> unit
(** [pp fmt t] pretty-prints progress information. *)

val v : total:int -> t
(** [v ~total] creates a new progress indicator with a progress bar. If [total]
    is 0 or the output is not a terminal, creates a no-op progress indicator. *)

val update : t -> current:int -> string -> unit
(** [update progress ~current message] updates the progress display with the
    current count and message. The progress bar shows percentage, elapsed time,
    and the message. *)

val clear : t -> unit
(** [clear progress] finalizes and clears the progress display. *)
