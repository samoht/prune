(** Configuration module exercising multiple warning types. *)

(** Warning 69: some fields are never read. *)
type connection = {
  host : string;
  port : int;
  timeout : float;
  debug_trace : bool;
  max_retries : int;
}

(** Warning 37: some constructors are never used. *)
type log_level =
  | Debug
  | Info
  | Warning
  | Error
  | Critical
  | Trace
  | Verbose

(** Warning 32: some values are never used externally. *)
val default_connection : connection
val make_connection : host:string -> port:int -> connection
val unused_helper : string -> string
val format_connection : connection -> string

val log_level_to_string : log_level -> string
val default_log_level : log_level
val unused_log_parser : string -> log_level option
