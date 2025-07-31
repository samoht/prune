(** Output formatting and display module *)

type mode = Normal | Quiet | Verbose | Json

val set_mode : mode -> unit
(** [set_mode mode] sets the output mode. *)

(** {2 Structured output} *)

val header : ('a, Format.formatter, unit) format -> 'a
(** [header fmt ...] prints a header. *)

val section : ('a, Format.formatter, unit) format -> 'a
(** [section fmt ...] prints a section header. *)

val success : ('a, Format.formatter, unit) format -> 'a
(** [success fmt ...] prints a success message. *)

val warning : ('a, Format.formatter, unit) format -> 'a
(** [warning fmt ...] prints a warning message. *)

val error : ('a, Format.formatter, unit) format -> 'a
(** [error fmt ...] prints an error message. *)

(** {2 Progress indicators} *)

type progress

val progress : ?total:int -> unit -> progress
(** [progress ?total ()] creates a progress indicator. *)

val update_progress : progress -> string -> unit
(** [update_progress progress message] updates progress with a message. *)

val set_progress_current : progress -> int -> unit
(** [set_progress_current progress value] sets current progress value. *)

val clear_progress : progress -> unit
(** [clear_progress progress] clears the progress display. *)
