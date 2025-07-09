(* Core types and utilities for prune *)

(* Error helper functions *)
let err fmt = Format.kasprintf (fun e -> Error (`Msg e)) fmt

let err_invalid_outline () =
  err "Invalid outline response: missing or invalid 'value' field"

let err_invalid_outline_format () =
  err "Invalid outline response: expected object"

let err_invalid_occurrences () =
  err "Invalid occurrences response: missing or invalid 'value' field"

let err_invalid_occurrences_format () =
  err "Invalid occurrences response: expected object"

(* {2 Location information} *)

type location = {
  file : string;
  start_line : int;
  start_col : int;
  end_line : int;
  end_col : int;
}

let extend ?start_line ~end_line ?end_col location =
  let start_line =
    match start_line with None -> location.start_line | Some n -> n
  in
  let end_col = match end_col with None -> location.end_col | Some n -> n in
  { location with start_line; end_line; end_col }

let merge loc1 loc2 =
  assert (loc1.file = loc2.file);
  {
    file = loc1.file;
    start_line = min loc1.start_line loc2.start_line;
    start_col =
      (if loc1.start_line < loc2.start_line then loc1.start_col
       else if loc2.start_line < loc1.start_line then loc2.start_col
       else min loc1.start_col loc2.start_col);
    end_line = max loc1.end_line loc2.end_line;
    end_col =
      (if loc1.end_line > loc2.end_line then loc1.end_col
       else if loc2.end_line > loc1.end_line then loc2.end_col
       else max loc1.end_col loc2.end_col);
  }

let relativize_path ~root_dir path =
  let root_dir = Fpath.v root_dir in
  let path_fpath = Fpath.v path in
  match Fpath.(relativize ~root:root_dir path_fpath) with
  | None -> path (* If can't relativize, return original path string *)
  | Some rel ->
      let rel_str = Fpath.to_string rel in
      (* Remove ./ prefix with simple string manipulation since Fpath doesn't do
         it *)
      if String.length rel_str >= 2 && String.sub rel_str 0 2 = "./" then
        String.sub rel_str 2 (String.length rel_str - 2)
      else rel_str

let location ~line ?(end_line = line) ~start_col ~end_col file =
  (* Normalize file path to remove ./ prefix if present *)
  let normalized_file =
    if String.length file >= 2 && String.sub file 0 2 = "./" then
      String.sub file 2 (String.length file - 2)
    else file
  in
  { file = normalized_file; start_line = line; start_col; end_line; end_col }

let pp_location ppf loc =
  if loc.start_line = loc.end_line then
    Format.fprintf ppf "%s:%d:%d-%d" loc.file loc.start_line loc.start_col
      loc.end_col
  else
    Format.fprintf ppf "%s:%d:%d-%d:%d" loc.file loc.start_line loc.start_col
      loc.end_line loc.end_col

(* {2 Symbol information} *)

type symbol_kind =
  | Value (* Functions, variables, etc. *)
  | Type (* Type declarations *)
  | Module (* Module declarations *)
  | Constructor (* Variant constructors *)
  | Field (* Record fields *)

let string_of_symbol_kind = function
  | Value -> "value"
  | Type -> "type"
  | Module -> "module"
  | Constructor -> "constructor"
  | Field -> "field"

let symbol_kind_of_string = function
  | "Value" -> Some Value
  | "Type" -> Some Type
  | "Module" -> Some Module
  | "Constructor" -> Some Constructor
  | "Field" -> Some Field
  | "Exn" ->
      Some Constructor (* Exception constructors are treated as constructors *)
  | "Signature" -> Some Module (* Module signatures are treated as modules *)
  | _ -> None

type symbol_info = { name : string; kind : symbol_kind; location : location }

(* {2 Occurrence information} *)

type usage_classification =
  | Unused
  | Used_only_in_excluded (* Used only in excluded directories *)
  | Used (* Used in at least one non-excluded location *)
  | Unknown
(* Cannot determine usage via occurrences (e.g., modules, exceptions) *)

let pp_usage_classification fmt = function
  | Unused -> Fmt.string fmt "unused"
  | Used_only_in_excluded -> Fmt.string fmt "excluded-only"
  | Used -> Fmt.string fmt "used"
  | Unknown -> Fmt.string fmt "unknown"

type occurrence_info = {
  symbol : symbol_info;
  occurrences : int;
  locations : location list;
  usage_class : usage_classification;
}

(* {2 Statistics} *)

type stats = {
  mli_exports_removed : int;
  ml_implementations_removed : int;
  iterations : int;
  lines_removed : int;
}

let empty_stats =
  {
    mli_exports_removed = 0;
    ml_implementations_removed = 0;
    iterations = 0;
    lines_removed = 0;
  }

let pp_stats fmt stats =
  if stats.iterations = 0 then ()
    (* Don't print anything - already handled by success message *)
  else
    Fmt.pf fmt
      "Summary: removed %d export%s and %d implementation%s in %d iteration%s \
       (%d line%s total)"
      stats.mli_exports_removed
      (if stats.mli_exports_removed = 1 then "" else "s")
      stats.ml_implementations_removed
      (if stats.ml_implementations_removed = 1 then "" else "s")
      stats.iterations
      (if stats.iterations = 1 then "" else "s")
      stats.lines_removed
      (if stats.lines_removed = 1 then "" else "s")

(* {2 Warning information} *)

type warning_type =
  | Unused_value (* Warning 32: unused value declaration *)
  | Unused_type (* Warning 34: unused type declaration *)
  | Unused_open (* Warning 33: unused open statement *)
  | Unused_constructor (* Warning 37: unused constructor *)
  | Unused_exception (* Warning 38: unused exception declaration *)
  | Unused_field (* Warning 69: unused record field definition *)
  | Unnecessary_mutable
    (* Warning 69: mutable record field that is never mutated *)
  | Signature_mismatch (* Compiler error: value required but not provided *)
  | Unbound_field (* Compiler error: unbound record field *)

(* Precision of location information from compiler warnings/errors *)
type location_precision =
  | Exact_definition
    (* Location covers the full definition that should be removed. Doc comments
       should be removed as they document the definition. *)
  | Exact_statement
    (* Location covers a full statement (like open) that should be removed. No
       doc comments to remove as statements don't have doc comments. *)
  | Needs_enclosing_definition
    (* Location is just an identifier, needs merlin enclosing to find full
       definition. Doc comments should be removed after finding enclosing. *)
  | Needs_field_usage_parsing
(* Location is field name in record construction, needs special parsing. No doc
   comments removal as we're removing usage, not definition. *)

let precision_of_warning_type = function
  | Unused_value -> Needs_enclosing_definition
  | Unused_type -> Exact_definition
  | Unused_open -> Exact_statement
  | Unused_constructor -> Exact_definition
  | Unused_exception -> Needs_enclosing_definition
  | Unused_field ->
      Exact_statement
      (* Precise character-level location for field definition *)
  | Unnecessary_mutable ->
      Exact_statement (* Precise character-level location for mutable keyword *)
  | Signature_mismatch -> Exact_definition
  | Unbound_field -> Needs_field_usage_parsing

let symbol_kind_of_warning = function
  | Unused_value -> Value
  | Unused_type -> Type
  | Unused_open -> Module (* Open statements relate to modules *)
  | Unused_constructor -> Constructor
  | Unused_exception -> Constructor (* Exceptions are constructors *)
  | Unused_field -> Field
  | Unnecessary_mutable -> Field
  | Signature_mismatch -> Value (* Usually values, but could be other kinds *)
  | Unbound_field -> Field (* Field usage that needs to be removed *)

let pp_warning_type fmt = function
  | Unused_value -> Fmt.string fmt "Unused_value"
  | Unused_type -> Fmt.string fmt "Unused_type"
  | Unused_open -> Fmt.string fmt "Unused_open"
  | Unused_constructor -> Fmt.string fmt "Unused_constructor"
  | Unused_exception -> Fmt.string fmt "Unused_exception"
  | Unused_field -> Fmt.string fmt "Unused_field"
  | Unnecessary_mutable -> Fmt.string fmt "Unnecessary_mutable"
  | Signature_mismatch -> Fmt.string fmt "Signature_mismatch"
  | Unbound_field -> Fmt.string fmt "Unbound_field"

type warning_info = {
  location : location;
  name : string;
  warning_type : warning_type;
  location_precision : location_precision;
}

let pp_location_precision fmt = function
  | Exact_definition -> Fmt.string fmt "Exact_definition"
  | Exact_statement -> Fmt.string fmt "Exact_statement"
  | Needs_enclosing_definition -> Fmt.string fmt "Needs_enclosing_definition"
  | Needs_field_usage_parsing -> Fmt.string fmt "Needs_field_usage_parsing"

let pp_warning_info fmt w =
  Fmt.pf fmt
    "{ location = %a; name = %S; warning_type = %a; location_precision = %a }"
    pp_location w.location w.name pp_warning_type w.warning_type
    pp_location_precision w.location_precision

(* {2 Build tracking} *)

type build_result = {
  success : bool;
  output : string;
  exit_code : int;
  warnings : warning_info list; (* Parsed warnings from build output *)
}

type context = {
  last_build_result : build_result option;
  previous_errors : string list; (* Track error messages to detect loops *)
}

(* {2 Error handling} *)

type error = [ `Msg of string | `Build_error of context ]

let pp_error ppf = function
  | `Msg s -> Format.fprintf ppf "%s" s
  | `Build_error _ctx -> Format.fprintf ppf "Build failed"

let empty_context = { last_build_result = None; previous_errors = [] }

let update_build_result ctx result =
  { ctx with last_build_result = Some result }

let get_last_build_result ctx = ctx.last_build_result

(* Build error classification *)
type build_error_type =
  | No_error
  | Fixable_errors of warning_info list
  | Other_errors of string

(* {2 Merlin response types} *)

(* Outline item from merlin *)
type outline_item = {
  kind : symbol_kind;
  name : string;
  location : location;
  children : outline_item list option;
}

(* Merlin response types *)
type outline_response = outline_item list
type occurrences_response = location list

(* JSON parsing functions *)
let position_of_json = function
  | `Assoc props -> (
      match (List.assoc_opt "line" props, List.assoc_opt "col" props) with
      | Some (`Int line), Some (`Int col) -> Some (line, col)
      | _ -> None)
  | _ -> None

(* Extract end position with fallback to start position *)
let extract_end_position end_json start_line start_col =
  match end_json with
  | Some pos -> (
      match position_of_json pos with
      | Some (el, ec) -> (el, ec)
      | None -> (start_line, start_col))
  | None -> (start_line, start_col)

(* Parse children items from JSON *)
let rec parse_children file_str props =
  match List.assoc_opt "children" props with
  | Some (`List children_json) ->
      let parsed_children =
        List.filter_map (outline_item_of_json file_str) children_json
      in
      if parsed_children = [] then None else Some parsed_children
  | _ -> None

and outline_item_of_json file_str = function
  | `Assoc props -> parse_outline_props file_str props
  | _ -> None

and parse_outline_props file_str props =
  match
    ( List.assoc_opt "kind" props,
      List.assoc_opt "name" props,
      List.assoc_opt "start" props,
      List.assoc_opt "end" props )
  with
  | Some (`String kind_str), Some (`String name), Some start_json, end_json ->
      parse_outline_item file_str kind_str name start_json end_json props
  | _ -> None

and parse_outline_item file_str kind_str name start_json end_json props =
  match symbol_kind_of_string kind_str with
  | None -> None (* Unknown kind, skip this item *)
  | Some kind -> (
      match position_of_json start_json with
      | None -> None
      | Some (start_line, start_col) ->
          let end_line, end_col =
            extract_end_position end_json start_line start_col
          in
          let location =
            { file = file_str; start_line; start_col; end_line; end_col }
          in
          let children = parse_children file_str props in
          Some { kind; name; location; children })

let occurrence_location_of_json file = function
  | `Assoc props -> (
      match (List.assoc_opt "start" props, List.assoc_opt "end" props) with
      | Some start_json, end_json -> (
          match position_of_json start_json with
          | None -> None
          | Some (start_line, start_col) ->
              let end_line, end_col =
                extract_end_position end_json start_line start_col
              in
              let file = file props in
              Some
                (location file ~line:start_line ~end_line ~start_col ~end_col))
      | _ -> None)
  | _ -> None

let outline_response_of_json ~file = function
  | `Assoc response -> (
      match List.assoc_opt "value" response with
      | Some (`List items) ->
          Ok (List.filter_map (outline_item_of_json file) items)
      | _ -> err_invalid_outline ())
  | _ -> err_invalid_outline_format ()

let occurrences_response_of_json ~root_dir = function
  | `Assoc response -> (
      match List.assoc_opt "value" response with
      | Some (`List items) ->
          let file props =
            match List.assoc_opt "file" props with
            | Some (`String f) -> relativize_path ~root_dir f
            | _ -> "" (* Default to empty string if no file field *)
          in
          Ok (List.filter_map (occurrence_location_of_json file) items)
      | _ -> err_invalid_occurrences ())
  | _ -> err_invalid_occurrences_format ()
