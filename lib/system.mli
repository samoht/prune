(** System utilities for prune - TTY detection, dune operations, and project
    validation *)

(** {2 TTY and environment detection} *)

val is_tty : unit -> bool
(** [is_tty ()] checks if we're running in a TTY (for progress display). *)

(** {2 Dune build operations} *)

val build_project_and_index :
  string -> Types.context -> (unit, [ `Build_failed of Types.context ]) result
(** [build_project_and_index root_dir ctx] builds project and index for
    analysis. Returns a custom error type to preserve context information for
    better error reporting. *)

val classify_build_error : Types.context -> Types.build_error_type
(** [classify_build_error ctx] analyzes the last build result and classifies the
    error type. *)

(** {2 Project validation} *)

val ocaml_version : unit -> string option
(** [ocaml_version ()] gets the OCaml compiler version string. *)

val check_ocaml_version : unit -> (unit, [ `Msg of string ]) result
(** [check_ocaml_version ()] checks if OCaml compiler version meets minimum
    requirements (5.3.0). *)

val validate_dune_project : string -> (unit, [ `Msg of string ]) result
(** [validate_dune_project root_dir] checks if directory contains a dune
    project. *)

val display_failure_and_exit : Types.context -> unit
(** [display_failure_and_exit ctx] displays build failure consistently and exits
    with the build's exit code. *)
