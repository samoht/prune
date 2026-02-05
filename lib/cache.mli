(** {1 File caching}

    Efficient caching of file contents for prune analysis operations. Files are
    read once and cached as line arrays to minimize I/O operations during symbol
    analysis and removal operations. *)

type t
(** The cache type. Handles file content caching and modification tracking. *)

val pp : Format.formatter -> t -> unit
(** [pp fmt t] pretty-prints cache information (file count and modification
    status). *)

(** {2 Cache operations} *)

val v : unit -> t
(** [v ()] creates a new empty cache. *)

val clear : t -> unit
(** [clear cache] removes all entries from the cache. *)

(** {2 File operations} *)

val load : t -> string -> (unit, [ `Msg of string ]) result
(** [load cache file] loads a file into the cache if not already present. *)

val line : t -> string -> int -> string option
(** [line cache file line_num] returns line [line_num] (1-indexed) from [file].
    Returns [None] if the file is not loaded or line number is out of bounds. *)

val replace_line : t -> string -> int -> string -> unit
(** [replace_line cache file line_num new_content] replaces line [line_num]
    (1-indexed) in [file] with [new_content]. Does nothing if file not loaded.
*)

val clear_line : t -> string -> int -> unit
(** [clear_line cache file line_num] replaces line [line_num] with an empty
    string. *)

val line_count : t -> string -> int option
(** [line_count cache file] returns the number of lines in [file], or [None] if
    the file is not loaded. *)

val has_changes : t -> string -> bool
(** [has_changes cache file] returns true if [file] has pending changes to be
    written. *)

val count_lines_removed : t -> int
(** [count_lines_removed cache] returns the total number of lines that were
    cleared across all files. *)

val is_file_empty : t -> string -> bool
(** [is_file_empty cache file] returns true if the file contains only blank
    lines. *)

(** {2 AST caching} *)

type ast_entry =
  | Implementation of Parsetree.structure
  | Interface of Parsetree.signature  (** AST representation for cached files *)

val ast : t -> string -> (ast_entry, [ `Msg of string ]) result
(** [ast cache file] returns the parsed AST for [file], parsing and caching it
    if necessary. Returns an error if the file is not loaded or parsing fails.
*)

(** {2 File content access} *)

val file_content : t -> string -> string option
(** [file_content cache file] returns the current content of [file] from cache
    as a single string. Returns [None] if the file is not loaded. *)

val write : t -> string -> (unit, [ `Msg of string ]) result
(** [write cache file] writes the cached content of [file] to disk. Returns an
    error if the file is not loaded or if the write fails. *)
