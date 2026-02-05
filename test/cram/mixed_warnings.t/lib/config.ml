(* Configuration module exercising multiple warning types. *)

type connection = {
  host : string;
  port : int;
  timeout : float;
  debug_trace : bool;
  max_retries : int;
}

type log_level =
  | Debug
  | Info
  | Warning
  | Error
  | Critical
  | Trace
  | Verbose

let default_connection =
  { host = "localhost"; port = 8080; timeout = 30.0; debug_trace = false; max_retries = 3 }

let make_connection ~host ~port =
  { host; port; timeout = 30.0; debug_trace = false; max_retries = 3 }

let unused_helper s = String.uppercase_ascii s ^ "!"

let format_connection c =
  Printf.sprintf "%s:%d (timeout=%.1f)" c.host c.port c.timeout

let log_level_to_string = function
  | Debug -> "DEBUG"
  | Info -> "INFO"
  | Warning -> "WARNING"
  | Error -> "ERROR"
  | Critical -> "CRITICAL"
  | Trace -> "TRACE"
  | Verbose -> "VERBOSE"

let default_log_level = Info

let unused_log_parser = function
  | "debug" -> Some Debug
  | "info" -> Some Info
  | "warning" -> Some Warning
  | "error" -> Some Error
  | _ -> None
