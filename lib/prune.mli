(** {1 Prune}

    Find and report unused exports from OCaml [.mli] interface files in dune
    projects. Uses merlin to analyze symbol usage across the entire project.

    This library is organized into several sub-modules:
    - Types: Core types and utilities (included in this module)
    - {!System}: System utilities (TTY, dune, merlin)
    - {!Analysis}: Symbol discovery and occurrence analysis
    - {!Removal}: File modification functions *)

(** {2 Types} *)

include module type of Types
(** Re-export core types for convenience *)

(** {2 System utilities} *)

type merlin_mode = [ `Single | `Server ]

val set_merlin_mode : merlin_mode -> unit
(** [set_merlin_mode mode] sets the merlin execution mode (single or server). *)

val stop_merlin_server : string -> unit
(** [stop_merlin_server root_dir] stops the merlin server in the given
    directory. *)

(** {2 Main interface functions} *)

type mode = [ `Dry_run | `Single_pass | `Iterative ]
(** Analysis mode:
    - [`Dry_run]: Only report what would be removed, don't modify files
    - [`Single_pass]: Remove unused exports once (no iterative cleanup)
    - [`Iterative]: Alternate between cleaning .mli and .ml files until fixpoint
*)

val analyze :
  ?yes:bool ->
  ?exclude_dirs:string list ->
  ?public_files:string list ->
  mode ->
  string ->
  string list ->
  (stats, error) result
(** [analyze ?yes ?exclude_dirs ?public_files mode root_dir mli_files] analyzes
    and optionally removes unused exports based on the specified mode. Returns
    statistics about the run. The [yes] parameter only affects confirmation
    prompts when removing code, not the analysis behavior. The [exclude_dirs]
    parameter specifies directories whose occurrences should be ignored when
    counting usage. The [public_files] parameter marks .mli files as public APIs
    whose exports should never be removed. *)

(** {2 Internal modules exposed for testing} *)

module System = System
(** Internal system module exposed for main.ml *)

module Removal = Removal
(** Internal removal module exposed for testing *)

module Cache = Cache
(** Internal cache module exposed for testing *)

module Analysis = Analysis
(** Internal analysis module exposed for testing *)

module Module_alias = Module_alias
(** Internal module_alias module exposed for testing *)

module Warning = Warning
(** Internal warning module exposed for testing *)

module Locate = Locate
(** Internal locate module exposed for testing *)

module Doctor = Doctor
(** Diagnostic tool for debugging merlin and build issues *)

module Show = Show
(** Symbol occurrence reporting tool *)

module Output = Output
(** Output system with different modes *)
