(** Occurrence checking and classification for symbols *)

open Types

val check_bulk :
  cache:Cache.t ->
  string list ->
  string ->
  symbol_info list ->
  occurrence_info list
(** [check_bulk ~cache exclude_dirs root_dir symbols] checks occurrences for a
    list of symbols with progress display. *)
