(** Diagnostic tool for debugging merlin and build issues *)

val run_diagnostics :
  string -> string option -> (unit, [ `Msg of string ]) result
(** [run_diagnostics root_dir sample_mli] runs all diagnostic checks. [root_dir]
    is the project root directory. [sample_mli] is an optional .mli file to test
    merlin occurrences on. *)
