(** Symbol discovery and analysis orchestration for prune *)

open Types

(** {2 Main analysis orchestration} *)

val unused_exports :
  cache:Cache.t ->
  ?exclude_dirs:string list ->
  string ->
  string list ->
  ( (string * occurrence_info list) list * (string * occurrence_info list) list,
    error )
  result
(** [unused_exports ~cache ?exclude_dirs root_dir mli_files] finds unused
    exports in the given .mli files within the project context. Returns
    (unused_by_file, excluded_only_by_file) where:
    - unused_by_file: symbols that are completely unused
    - excluded_only_by_file: symbols that are only used in excluded directories.
*)

(** {2 Functions for other analysis tools} *)

val all_symbol_occurrences :
  cache:Cache.t ->
  ?exclude_dirs:string list ->
  string ->
  string list ->
  (occurrence_info list, error) result
(** [all_symbol_occurrences ~cache ?exclude_dirs root_dir mli_files] gets
    occurrence information for all symbols in the given .mli files. Unlike
    find_unused_exports, this returns all symbols regardless of usage. *)

(** {2 Internal functions exposed for testing} *)

val filter_modules_with_used :
  occurrence_info list -> occurrence_info list -> occurrence_info list
(** [filter_modules_with_used unused_symbols all_occurrence_data] filters out
    modules from the unused list that contain any used symbols. *)
