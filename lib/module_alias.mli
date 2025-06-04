(** Module alias detection for OCaml code *)

val is_module_alias :
  cache:Cache.t ->
  string ->
  Types.symbol_kind ->
  Types.location ->
  string ->
  bool
(** [is_module_alias ~cache file symbol_kind loc content] checks if a module
    declaration is a module type alias in .mli files *)

(** {2 Regular expressions exposed for testing} *)

val ws : Re.t
(** Matches zero or more whitespace characters *)

val ws1 : Re.t
(** Matches one or more whitespace characters *)

val module_name : Re.t
(** Matches a valid OCaml module name *)
