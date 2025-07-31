(** File modification functions for removing unused exports and implementations
*)

open Types

(** {2 Warning-based removal} *)

val remove_warnings :
  cache:Cache.t -> string -> warning_info list -> (int, error) result
(** [remove_warnings ~cache root_dir warnings] removes unused code based on
    compiler warnings (32/33/34/69 etc) in any file type. *)

(** {2 .mli file modification} *)

val remove_unused_exports :
  cache:Cache.t -> string -> string -> symbol_info list -> (unit, error) result
(** [remove_unused_exports ~cache root_dir file symbols] removes unused exports
    from a file. Takes root_dir, file path, and symbols to remove. *)
