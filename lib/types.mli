(** Core types and utilities for prune *)

(** {2 Location information} *)

type location = private {
  file : string;
  start_line : int;
  start_col : int;
  end_line : int;
  end_col : int;
}

val extend :
  ?start_line:int -> end_line:int -> ?end_col:int -> location -> location

val merge : location -> location -> location

val location :
  line:int ->
  ?end_line:int ->
  start_col:int ->
  end_col:int ->
  string ->
  location
(** Create a location for a single line *)

val pp_location : Format.formatter -> location -> unit
(** Pretty-print a location *)

(** {2 Symbol information} *)

type symbol_kind =
  | Value  (** Functions, variables, etc. *)
  | Type  (** Type declarations *)
  | Module  (** Module declarations *)
  | Constructor  (** Variant constructors *)
  | Field  (** Record fields *)

val string_of_symbol_kind : symbol_kind -> string
(** Convert symbol kind to lowercase string for user-facing display *)

type symbol_info = { name : string; kind : symbol_kind; location : location }

(** {2 Occurrence information} *)

type usage_classification =
  | Unused
  | Used_only_in_excluded  (** Used only in excluded directories *)
  | Used  (** Used in at least one non-excluded location *)
  | Unknown
      (** Cannot determine usage via occurrences (e.g., modules, exceptions) *)

val pp_usage_classification : Format.formatter -> usage_classification -> unit
(** Pretty-print a usage classification *)

type occurrence_info = {
  symbol : symbol_info;
  occurrences : int;
  locations : location list;
  usage_class : usage_classification;
}

(** {2 Statistics} *)

type stats = {
  mli_exports_removed : int;
  ml_implementations_removed : int;
  iterations : int;
  lines_removed : int;
}
(** Statistics about a prune run *)

val empty_stats : stats
(** Empty statistics record *)

val pp_stats : Format.formatter -> stats -> unit
(** Pretty-print statistics *)

(** {2 Warning information} *)

type warning_type =
  | Unused_value  (** Warning 32: unused value declaration *)
  | Unused_type  (** Warning 34: unused type declaration *)
  | Unused_open  (** Warning 33: unused open statement *)
  | Unused_constructor  (** Warning 37: unused constructor *)
  | Unused_exception  (** Warning 38: unused exception declaration *)
  | Unused_field  (** Warning 69: unused record field definition *)
  | Unnecessary_mutable
      (** Warning 69: mutable record field that is never mutated *)
  | Signature_mismatch  (** Compiler error: value required but not provided *)
  | Unbound_field  (** Compiler error: unbound record field *)

val pp_warning_type : Format.formatter -> warning_type -> unit
(** Pretty-print a warning type *)

(** Precision of location information from compiler warnings/errors *)
type location_precision =
  | Exact_definition
      (** Location covers the full definition that should be removed. Doc
          comments should be removed as they document the definition. *)
  | Exact_statement
      (** Location covers a full statement (like open) that should be removed.
          No doc comments to remove as statements don't have doc comments. *)
  | Needs_enclosing_definition
      (** Location is just an identifier, needs merlin enclosing to find full
          definition. Doc comments should be removed after finding enclosing. *)
  | Needs_field_usage_parsing
      (** Location is field name in record construction, needs special parsing.
          No doc comments removal as we're removing usage, not definition. *)

val location_precision_of_warning_type : warning_type -> location_precision
(** Get the location precision for a given warning type *)

val symbol_kind_of_warning_type : warning_type -> symbol_kind
(** Convert warning type to symbol kind *)

type warning_info = {
  location : location;
  name : string;
  warning_type : warning_type;
  location_precision : location_precision;
}

val pp_warning_info : Format.formatter -> warning_info -> unit
(** Pretty-print a warning info *)

(** {2 Build tracking} *)

type build_result = {
  success : bool;
  output : string;
  exit_code : int;
  warnings : warning_info list; (* Parsed warnings from build output *)
}
(** Result of a build operation *)

type context
(** Context for tracking build state across operations *)

val empty_context : context
(** Empty context with no build result *)

(** {2 Error handling} *)

type error = [ `Msg of string | `Build_error of context ]

val pp_error : Format.formatter -> error -> unit

val update_build_result : context -> build_result -> context
(** Update context with a new build result *)

val get_last_build_result : context -> build_result option
(** Get the last build result from context *)

(** Build error classification *)
type build_error_type =
  | No_error  (** Build succeeded *)
  | Fixable_errors of warning_info list
      (** Errors that prune might be able to fix *)
  | Other_errors of string  (** Any other build errors - show full output *)

(** {2 Merlin response types} *)

type outline_item = {
  kind : symbol_kind;
  name : string;
  location : location;
  children : outline_item list option;
}
(** Outline item from merlin *)

type outline_response = outline_item list
(** Merlin response types *)

type occurrences_response = location list

val outline_response_of_json :
  file:string -> Yojson.Safe.t -> (outline_response, error) result
(** JSON parsing functions *)

val occurrences_response_of_json :
  root_dir:string -> Yojson.Safe.t -> (occurrences_response, error) result
