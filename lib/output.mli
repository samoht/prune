(** Output formatting and display module *)

type output_mode = Normal | Quiet | Verbose | Json

val set_mode : output_mode -> unit
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

val create_progress : ?total:int -> unit -> progress
(** [create_progress ?total ()] creates a progress indicator. *)

val update_progress : progress -> string -> unit
(** Update progress with a message *)

val set_progress_current : progress -> int -> unit
(** Set current progress value *)

val clear_progress : progress -> unit
(** Clear the progress display *)
