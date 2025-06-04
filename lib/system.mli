(** System utilities for prune - TTY detection, dune operations, and merlin
    communication *)

(** {2 TTY and environment detection} *)

val is_tty : unit -> bool
(** Check if we're running in a TTY (for progress display) *)

(** {2 Merlin communication} *)

type merlin_mode = [ `Single | `Server ]

val set_merlin_mode : merlin_mode -> unit
(** [set_merlin_mode mode] sets the merlin execution mode (single or server) *)

val call_merlin : string -> string -> string -> Yojson.Safe.t
(** [call_merlin root_dir file_path query] runs merlin command on the given file
*)

val stop_merlin_server : string -> unit
(** [stop_merlin_server root_dir] stops the merlin server in the given directory
*)

(** {2 Dune build operations} *)

val build_project_and_index :
  string -> Types.context -> (unit, [ `Build_failed of Types.context ]) result
(** Build project and index for analysis. Returns a custom error type to
    preserve context information for better error reporting. *)

val classify_build_error : Types.context -> Types.build_error_type
(** Analyze the last build result and classify the error type *)

(** {2 Project validation} *)

val get_ocaml_version : unit -> string option
(** Get the OCaml compiler version string *)

val check_ocaml_version : unit -> (unit, [ `Msg of string ]) result
(** Check if OCaml compiler version meets minimum requirements (5.3.0) *)

val validate_dune_project : string -> (unit, [ `Msg of string ]) result
(** Check if directory contains a dune project *)

val display_build_failure_and_exit : Types.context -> 'a
(** Display build failure consistently and exit with the build's exit code *)
