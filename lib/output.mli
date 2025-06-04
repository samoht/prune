(** Output formatting and display module *)

type output_mode = Normal | Quiet | Verbose | Json

val set_mode : output_mode -> unit
(** Set the output mode *)

val get_mode : unit -> output_mode
(** Get the current output mode *)

(** {2 Basic output functions} *)

val print : ('a, Format.formatter, unit) format -> 'a
(** Print a message to stdout *)

val eprint : ('a, Format.formatter, unit) format -> 'a
(** Print a message to stderr *)

val verbose : ('a, Format.formatter, unit) format -> 'a
(** Print only in verbose mode *)

(** {2 Structured output} *)

val header : ('a, Format.formatter, unit) format -> 'a
(** Print a header *)

val section : ('a, Format.formatter, unit) format -> 'a
(** Print a section header *)

val info : ('a, Format.formatter, unit) format -> 'a
(** Print an info message *)

val success : ('a, Format.formatter, unit) format -> 'a
(** Print a success message *)

val warning : ('a, Format.formatter, unit) format -> 'a
(** Print a warning message *)

val error : ('a, Format.formatter, unit) format -> 'a
(** Print an error message *)

(** {2 Progress indicators} *)

type progress

val create_progress : ?total:int -> unit -> progress
(** Create a progress indicator *)

val update_progress : progress -> string -> unit
(** Update progress with a message *)

val set_progress_current : progress -> int -> unit
(** Set current progress value *)

val clear_progress : progress -> unit
(** Clear the progress display *)
