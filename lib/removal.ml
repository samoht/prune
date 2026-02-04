(* File modification functions for removing unused exports and
   implementations *)

open Types
module Log = (val Logs.src_log (Logs.Src.create "prune.removal") : Logs.LOG)

(* Error helper functions *)
let err fmt = Fmt.kstr (fun e -> Error (`Msg e)) fmt
let err_file_read file msg = err "Failed to read %s: %s" file msg
let err_file_write file msg = err "Failed to write %s: %s" file msg

let err_field_info_detection msg =
  Fmt.failwith "Field info detection failed: %s" msg

let err_no_type_eq line =
  Fmt.failwith "Expected to find '=' in type declaration at line %d" line

let err_ast_bounds_failed msg =
  Fmt.failwith "AST-based item bounds detection failed: %s" msg

(* Warning helpers *)

let warn_file_read_failed file msg =
  Log.warn (fun m -> m "Failed to read %s: %s" file msg)

(* {1 Core removal strategy types} *)

type strategy =
  | Line_removal of { include_comments : bool }
  | Character_removal of character_removal_type

and character_removal_type =
  | Field_definition (* Remove field from type definition *)
  | Field_usage (* Remove field from record construction *)
  | Open_statement (* Remove open statement *)
  | Mutable_keyword (* Remove mutable keyword from field definition *)

type operation = { location : location; strategy : strategy; context : context }
and context = { warning : warning_info; enclosing : location option }

type result =
  | Lines_removed of bool array (* Array of bools indicating lines to remove *)
  | Characters_replaced of (int * string) list (* (line_idx, new_content) *)

(* {1 Strategy determination} *)

(* Determine the removal strategy based on warning type and context *)
let determine_removal_strategy (warning : warning_info) : strategy =
  match warning.warning_type with
  | Unused_field -> Character_removal Field_definition
  | Unnecessary_mutable -> Character_removal Mutable_keyword
  | Unbound_field -> Character_removal Field_usage
  | Unused_open -> Character_removal Open_statement
  | Unused_value | Unused_type | Unused_constructor | Unused_exception
  | Signature_mismatch ->
      let include_comments =
        match warning.location_precision with
        | Exact_definition | Needs_enclosing_definition -> true
        | Exact_statement | Needs_field_usage_parsing -> false
      in
      Line_removal { include_comments }

(* {1 Helper functions} *)

(* {1 Enclosing expression handling} *)

(* Get enclosing expression for a given position *)
(* Handle exact bounds with optional attributes *)
let handle_exact_bounds ~cache ~file ~line ~col include_attributes =
  if include_attributes then (
    match Locate.item_with_docs ~cache ~file ~line ~col with
    | Error (`Msg msg) -> err_ast_bounds_failed msg
    | Ok loc ->
        Log.debug (fun m ->
            m "get_item_with_docs returned location %d-%d for %s:%d:%d"
              loc.start_line loc.end_line file line col);
        Some loc)
  else None (* Use the exact bounds provided *)

(* Handle value binding lookup with fallback *)
let handle_value_binding ~cache ~file ~line ~col =
  match Locate.value_binding ~cache ~file ~line ~col with
  | Error (`Msg msg) -> (
      (* If we can't find a value binding, fall back to standard item detection
         but log a warning as this might indicate an issue *)
      Log.warn (fun m ->
          m
            "Could not find value binding at %s:%d:%d (%s), falling back to \
             item detection"
            file line col msg);
      match Locate.item_with_docs ~cache ~file ~line ~col with
      | Error (`Msg msg2) -> err_ast_bounds_failed msg2
      | Ok loc -> Some loc)
  | Ok loc -> Some loc

(* Handle other symbol kinds *)
let handle_other_kinds ~cache ~file ~line ~col =
  match Locate.item_with_docs ~cache ~file ~line ~col with
  | Error (`Msg msg) -> err_ast_bounds_failed msg
  | Ok loc -> Some loc

let enclosing_expression _root_dir file line col ~location_precision ~kind
    ~name:_ ~cache ~include_attributes : location option =
  match location_precision with
  | Exact_definition | Exact_statement ->
      handle_exact_bounds ~cache ~file ~line ~col include_attributes
  | Needs_enclosing_definition -> (
      match kind with
      | Value -> handle_value_binding ~cache ~file ~line ~col
      | _ -> handle_other_kinds ~cache ~file ~line ~col)
  | Needs_field_usage_parsing ->
      failwith "Field usage parsing should be handled in operation, not here"

(* {1 Field handling} *)

(* {1 Line-level removal} *)

(* Mark lines for removal *)
let mark_lines_for_removal cache file start_line end_line =
  match Cache.line_count cache file with
  | None -> Array.make 0 false
  | Some line_count ->
      let to_remove = Array.make line_count false in
      (* Mark all lines in the range *)
      for line_idx = start_line - 1 to end_line - 1 do
        if line_idx >= 0 && line_idx < line_count then
          to_remove.(line_idx) <- true
      done;
      to_remove

(* Process line-level removal operation *)
let process_line_removal cache file operation =
  match operation.strategy with
  | Line_removal { include_comments = _ } ->
      let loc =
        match operation.context.enclosing with
        | Some enc ->
            Log.debug (fun m ->
                m "Using enclosing location for %s: %d-%d (original: %d-%d)"
                  operation.context.warning.name enc.start_line enc.end_line
                  operation.location.start_line operation.location.end_line);
            enc
        | None ->
            Log.debug (fun m ->
                m "Using original location for %s: %d-%d"
                  operation.context.warning.name operation.location.start_line
                  operation.location.end_line);
            operation.location
      in
      let to_remove =
        mark_lines_for_removal cache file loc.start_line loc.end_line
      in
      Lines_removed to_remove
  | _ -> failwith "process_line_removal called with non-line removal strategy"

(* {1 Character-level removal} *)

(* Replace characters in a line with spaces *)
let replace_line_range line start_col end_col =
  if start_col >= 0 && end_col <= String.length line then (
    let bytes = Bytes.of_string line in
    for i = start_col to end_col - 1 do
      if i < Bytes.length bytes then Bytes.set bytes i ' '
    done;
    Bytes.to_string bytes)
  else line

(* Handle single-line field removal *)
let handle_single_line_field ~is_definition cache file loc replacements =
  let line_idx = loc.start_line - 1 in
  match Cache.line cache file loc.start_line with
  | None -> ()
  | Some line ->
      let start_col =
        if is_definition then loc.start_col else loc.start_col - 1
      in
      let new_line = replace_line_range line start_col loc.end_col in
      Log.debug (fun m ->
          m "Replacing cols %d-%d in '%s' (%s)" start_col loc.end_col line
            (if is_definition then "definition" else "usage"));
      replacements := [ (line_idx, new_line) ]

(* Handle multi-line field removal *)
let handle_multi_line_field cache file loc replacements =
  (* Replace first line *)
  let first_line_idx = loc.start_line - 1 in
  (match Cache.line cache file loc.start_line with
  | None -> ()
  | Some first_line ->
      let new_first =
        replace_line_range first_line (loc.start_col - 1)
          (String.length first_line)
      in
      replacements := [ (first_line_idx, new_first) ]);
  (* Clear intermediate lines *)
  for i = loc.start_line to loc.end_line - 2 do
    replacements := (i, "") :: !replacements
  done;
  (* Handle last line *)
  let last_line_idx = loc.end_line - 1 in
  match Cache.line cache file loc.end_line with
  | None -> ()
  | Some last_line ->
      let new_last = replace_line_range last_line 0 loc.end_col in
      replacements := (last_line_idx, new_last) :: !replacements

(* Process field definition removal *)
(* Generic field removal processing *)
let process_field_removal ~is_definition _root_dir file cache operation =
  let warning = operation.context.warning in

  (* First, get comprehensive field info to check if this would create an empty
     record *)
  match
    Locate.field_info ~cache ~file ~line:warning.location.start_line
      ~col:warning.location.start_col ~field_name:warning.name
  with
  | Error (`Msg msg) -> err_field_info_detection msg
  | Ok field_info ->
      (* Use the proper field bounds from field_info *)
      let loc = field_info.full_field_bounds in
      let replacements = ref [] in

      if loc.start_line = loc.end_line then
        handle_single_line_field ~is_definition cache file loc replacements
      else handle_multi_line_field cache file loc replacements;
      Characters_replaced (List.rev !replacements)

(* Wrapper functions for specific field removal types *)
let process_field_definition_removal = process_field_removal ~is_definition:true
let process_field_usage_removal = process_field_removal ~is_definition:false

(* Process open statement removal *)
let process_open_removal cache file operation =
  let line_idx = operation.location.start_line - 1 in
  match Cache.line cache file operation.location.start_line with
  | Some _ -> Characters_replaced [ (line_idx, "") ]
  | None -> Characters_replaced []

(* Process mutable keyword removal *)
let process_mutable_keyword_removal cache file operation =
  let line_idx = operation.location.start_line - 1 in
  match Cache.line cache file operation.location.start_line with
  | Some line_content -> (
      (* Find and remove the "mutable " keyword (including the space after
         it) *)
      let mutable_re = Re.(compile (seq [ str "mutable"; space ])) in
      try
        let _ = Re.exec mutable_re line_content in
        let new_content = Re.replace_string mutable_re ~by:"" line_content in
        Characters_replaced [ (line_idx, new_content) ]
      with Not_found ->
        Log.err (fun m ->
            m "Could not find 'mutable' keyword in line: %s" line_content);
        Characters_replaced [])
  | None -> Characters_replaced []

(* Process character-level removal operation *)
let process_character_removal root_dir file cache operation =
  match operation.strategy with
  | Character_removal removal_type -> (
      match removal_type with
      | Field_definition ->
          process_field_definition_removal root_dir file cache operation
      | Field_usage -> process_field_usage_removal root_dir file cache operation
      | Open_statement -> process_open_removal cache file operation
      | Mutable_keyword -> process_mutable_keyword_removal cache file operation)
  | _ ->
      failwith
        "process_character_removal called with non-character removal strategy"

(* {1 Operation creation} *)

(* Create removal operation from warning *)
let operation root_dir file cache (warning : warning_info) : operation =
  let strategy = determine_removal_strategy warning in
  let enclosing =
    match (warning.location_precision, strategy) with
    | Needs_enclosing_definition, Line_removal { include_comments } ->
        Log.debug (fun m ->
            m "Getting enclosing expression for %s (Needs_enclosing_definition)"
              warning.name);
        enclosing_expression root_dir file warning.location.start_line
          warning.location.start_col
          ~location_precision:warning.location_precision
          ~kind:(Types.symbol_kind_of_warning warning.warning_type)
          ~name:warning.name ~cache ~include_attributes:include_comments
    | Exact_definition, Line_removal { include_comments }
      when warning.warning_type = Signature_mismatch
           && Filename.check_suffix file ".mli" ->
        Log.debug (fun m ->
            m
              "Extending location for %s (Signature_mismatch in .mli) \
               include_comments=%b"
              warning.name include_comments);
        (* For signature mismatches in .mli files, directly extend the location
           with comments rather than trying to find the AST item *)
        if include_comments then
          Some
            (Comments.extend_location_with_comments cache file warning.location)
        else None
    | Needs_field_usage_parsing, Character_removal Field_usage -> (
        (* For field usage, use the new comprehensive field info *)
        match
          Locate.field_info ~cache ~file ~line:warning.location.start_line
            ~col:warning.location.start_col ~field_name:warning.name
        with
        | Error (`Msg msg) -> err_field_info_detection msg
        | Ok field_info ->
            (* Store the field info for later use *)
            Some field_info.full_field_bounds)
    | _ -> None
  in
  let context = { warning; enclosing } in
  { location = warning.location; strategy; context }

(* {1 Result application} *)

(* Apply removal result to cache *)
let apply_result file cache result context =
  match result with
  | Lines_removed to_remove ->
      Log.debug (fun m ->
          m "Applying line removal for %s: %d lines marked" context.warning.name
            (Array.fold_left
               (fun acc b -> if b then acc + 1 else acc)
               0 to_remove));
      Array.iteri
        (fun i should_remove ->
          if should_remove then (
            Log.debug (fun m -> m "  Clearing line %d" (i + 1));
            Cache.clear_line cache file (i + 1)))
        to_remove
  | Characters_replaced replacements ->
      List.iter
        (fun (line_idx, new_content) ->
          Cache.replace_line cache file (line_idx + 1) new_content)
        replacements

(* {1 Public API} *)

(* Check if it's safe to delete an empty file *)
let can_delete_empty_file file =
  if Filename.check_suffix file ".mli" then
    (* Don't delete .mli if corresponding .ml exists *)
    let ml_file = Filename.chop_suffix file ".mli" ^ ".ml" in
    not (Sys.file_exists ml_file)
  else if Filename.check_suffix file ".ml" then
    (* Don't delete .ml if corresponding .mli exists *)
    let mli_file = Filename.chop_suffix file ".ml" ^ ".mli" in
    not (Sys.file_exists mli_file)
  else
    (* For other files, it's safe to delete if empty *)
    true

(* Process a single removal operation *)
let process_operation root_dir file cache operation =
  match operation.strategy with
  | Line_removal _ -> process_line_removal cache file operation
  | Character_removal _ ->
      process_character_removal root_dir file cache operation

(* Remove unused exports from a file *)
(* Convert symbols to warnings for uniform processing *)
let symbols_to_warnings symbols =
  List.map
    (fun (sym : symbol_info) ->
      {
        location = sym.location;
        name = sym.name;
        warning_type = Signature_mismatch;
        location_precision = Exact_definition;
      })
    symbols

(* Process removal operations for loaded symbols *)
let process_operations root_dir file cache symbols =
  let warnings = symbols_to_warnings symbols in
  let operations = List.map (operation root_dir file cache) warnings in
  List.iter
    (fun op ->
      Log.debug (fun m ->
          m "Processing removal for %s at %s:%d-%d (enclosing: %s)"
            op.context.warning.name file op.location.start_line
            op.location.end_line
            (match op.context.enclosing with
            | None -> "none"
            | Some enc -> Fmt.str "%d-%d" enc.start_line enc.end_line));
      let result = process_operation root_dir file cache op in
      apply_result file cache result op.context)
    operations

(* Handle file deletion or writing after removals *)
let handle_file_after_removal cache file =
  if Cache.is_file_empty cache file && can_delete_empty_file file then (
    Log.info (fun m -> m "File %s is now empty, deleting it" file);
    match Bos.OS.File.delete (Fpath.v file) with
    | Ok () ->
        Log.info (fun m -> m "Successfully deleted empty file %s" file);
        Ok ()
    | Error (`Msg msg) -> (
        Log.warn (fun m -> m "Failed to delete empty file %s: %s" file msg);
        (* Fall back to writing the empty file *)
        match Cache.write cache file with
        | Ok () -> Ok ()
        | Error (`Msg m) -> err_file_write file m))
  else
    match Cache.write cache file with
    | Ok () -> Ok ()
    | Error (`Msg m) -> err_file_write file m

let remove_unused_exports ~cache root_dir file (symbols : symbol_info list) =
  Log.info (fun m ->
      m "remove_unused_exports called for %s with %d symbols" file
        (List.length symbols));
  (* Skip if no symbols to remove *)
  if symbols = [] then Ok ()
  else
    (* Ensure file is loaded into cache *)
    match Cache.load cache file with
    | Error (`Msg m) -> err_file_read file m
    | Ok () -> (
        process_operations root_dir file cache symbols;
        (* Only write cache if there were actual changes made *)
        match Cache.has_changes cache file with
        | false -> Ok ()
        | true -> handle_file_after_removal cache file)

(* Remove unused code based on compiler warnings *)
(* Group warnings by their file path *)
let group_warnings_by_file warnings =
  List.fold_left
    (fun acc (warning : warning_info) ->
      let file = warning.location.file in
      let existing = try List.assoc file acc with Not_found -> [] in
      (file, warning :: existing) :: List.remove_assoc file acc)
    [] warnings

(* Get field info for operations *)
let field_infos ~cache ~file ops =
  List.filter_map
    (fun op ->
      match
        Locate.field_info ~cache ~file ~line:op.location.start_line
          ~col:op.location.start_col ~field_name:op.context.warning.name
      with
      | Ok info -> Some (op, info)
      | Error _ -> None)
    ops

(* Group operations by record *)
let group_by_record field_infos =
  List.fold_left
    (fun acc (op, info) ->
      let key =
        ( info.Locate.enclosing_record.start_line,
          info.Locate.enclosing_record.start_col )
      in
      let existing = try List.assoc key acc with Not_found -> [] in
      (key, (op, info) :: existing) :: List.remove_assoc key acc)
    [] field_infos

(* Replace a type definition's record with unit *)
let replace_type_with_unit cache file loc =
  (* Use AST to find the type definition and its equals sign *)
  match
    Locate.type_definition_info ~cache ~file ~line:loc.start_line
      ~col:loc.start_col
  with
  | Error (`Msg msg) ->
      Log.err (fun m -> m "Failed to get type definition info: %s" msg);
      (* Fallback to the record location if we can't find the type def *)
      Cache.replace_line cache file loc.start_line " unit";
      for i = loc.start_line + 1 to loc.end_line do
        Cache.clear_line cache file i
      done
  | Ok type_info -> (
      match type_info.equals_loc with
      | None ->
          Log.err (fun m ->
              m "Type definition has no equals sign at line %d" loc.start_line);
          err_no_type_eq loc.start_line
      | Some eq_loc -> (
          (* Replace from after the equals sign to the end with " unit" *)
          match Cache.line cache file eq_loc.start_line with
          | None -> ()
          | Some line ->
              let before_eq_and_eq = String.sub line 0 eq_loc.end_col in
              Cache.replace_line cache file eq_loc.start_line
                (before_eq_and_eq ^ " unit");
              (* Clear any additional lines that were part of the record *)
              for i = eq_loc.start_line + 1 to loc.end_line do
                Cache.clear_line cache file i
              done))

(* Replace a record construction with () *)
let replace_record_with_unit cache file loc =
  if loc.start_line = loc.end_line then
    match Cache.line cache file loc.start_line with
    | None -> ()
    | Some line ->
        let before =
          if loc.start_col > 0 then String.sub line 0 loc.start_col else ""
        in
        let after =
          if loc.end_col < String.length line then
            String.sub line loc.end_col (String.length line - loc.end_col)
          else ""
        in
        Cache.replace_line cache file loc.start_line (before ^ "()" ^ after)
  else
    (* Multi-line record *)
    match Cache.line cache file loc.start_line with
    | None -> ()
    | Some first_line -> (
        let before =
          if loc.start_col > 0 then String.sub first_line 0 loc.start_col
          else ""
        in
        Cache.replace_line cache file loc.start_line (before ^ "()");
        (* Clear remaining lines *)
        for i = loc.start_line + 1 to loc.end_line - 1 do
          Cache.clear_line cache file i
        done;
        (* Handle last line *)
        match Cache.line cache file loc.end_line with
        | None -> ()
        | Some last_line ->
            let after =
              if loc.end_col < String.length last_line then
                String.sub last_line loc.end_col
                  (String.length last_line - loc.end_col)
              else ""
            in
            Cache.replace_line cache file loc.end_line after)

(* Process all field operations together *)
let process_field_removals ~cache ~root_dir ~file field_ops =
  let field_infos = field_infos ~cache ~file field_ops in
  let by_record = group_by_record field_infos in

  Log.debug (fun m ->
      m "Processing %d field operations across %d records"
        (List.length field_infos) (List.length by_record));

  (* Process each record *)
  List.iter
    (fun (_, ops_for_record) ->
      match ops_for_record with
      | [] -> ()
      | (_, first_info) :: _ -> (
          let fields_to_remove = List.length ops_for_record in
          let total_fields = first_info.Locate.total_fields in
          let is_last_field = fields_to_remove = total_fields in
          let field_context = first_info.Locate.context in
          let loc = first_info.Locate.enclosing_record in

          (* Use single match statement for all field removal decisions *)
          match (is_last_field, field_context) with
          | true, `Type_definition ->
              Log.info (fun m ->
                  m
                    "Removing all %d fields from record at line %d - replacing \
                     with unit"
                    total_fields loc.start_line);
              replace_type_with_unit cache file loc
          | true, `Record_construction ->
              Log.info (fun m ->
                  m
                    "Removing all %d fields from record construction at line \
                     %d - replacing with ()"
                    total_fields loc.start_line);
              replace_record_with_unit cache file loc
          | false, _ ->
              (* Not removing all fields - process each field individually *)
              List.iter
                (fun (op, _) ->
                  let result = process_operation root_dir file cache op in
                  apply_result file cache result op.context)
                ops_for_record))
    by_record

(* Group field operations by their type *)
let partition_field_operations operations =
  let field_def_ops, temp_ops =
    List.partition
      (fun op ->
        match op.strategy with
        | Character_removal Field_definition -> true
        | _ -> false)
      operations
  in
  let field_usage_ops, other_ops =
    List.partition
      (fun op ->
        match op.strategy with
        | Character_removal Field_usage -> true
        | _ -> false)
      temp_ops
  in
  (field_def_ops, field_usage_ops, other_ops)

(* Collect results and compute total *)
let collect_results results =
  let errors =
    List.filter_map (function Error e -> Some e | Ok _ -> None) results
  in
  let successes =
    List.filter_map
      (function Ok count -> Some count | Error _ -> None)
      results
  in
  let total_removed = List.fold_left ( + ) 0 successes in
  if errors = [] then Ok total_removed else Error (List.hd errors)

(* Process warnings for a single file *)
let process_file_warnings ~cache ~root_dir ~file file_warnings =
  match Cache.load cache file with
  | Error (`Msg msg) ->
      warn_file_read_failed file msg;
      err_file_read file msg
  | Ok () -> (
      (* Create removal operations for all warnings *)
      let operations = List.map (operation root_dir file cache) file_warnings in

      (* Group field operations *)
      let field_def_ops, field_usage_ops, other_ops =
        partition_field_operations operations
      in

      (* Process field removals with grouping *)
      let all_field_ops = field_def_ops @ field_usage_ops in
      process_field_removals ~cache ~root_dir ~file all_field_ops;

      (* Process other operations normally *)
      List.iter
        (fun op ->
          let result = process_operation root_dir file cache op in
          apply_result file cache result op.context)
        other_ops;

      (* Check if file is now empty and should be deleted *)
      if Cache.is_file_empty cache file && can_delete_empty_file file then (
        Log.info (fun m -> m "File %s is now empty, deleting it" file);
        match Bos.OS.File.delete (Fpath.v file) with
        | Ok () ->
            Log.info (fun m -> m "Successfully deleted empty file %s" file);
            Ok (List.length file_warnings)
        | Error (`Msg msg) -> (
            Log.warn (fun m -> m "Failed to delete empty file %s: %s" file msg);
            (* Fall back to writing the empty file *)
            match Cache.write cache file with
            | Ok () -> Ok (List.length file_warnings)
            | Error (`Msg m) -> err_file_write file m))
      else
        (* Write back to file *)
        match Cache.write cache file with
        | Ok () ->
            Log.info (fun m ->
                m "Successfully removed %d item(s) from %s"
                  (List.length file_warnings)
                  file);
            Ok (List.length file_warnings)
        | Error (`Msg m) -> err_file_write file m)

let remove_warnings ~cache root_dir warnings =
  (* Group warnings by file *)
  let by_file = group_warnings_by_file warnings in
  let total_files = List.length by_file in
  let processed = ref 0 in
  let progress = Progress.v ~total:total_files in
  let results =
    List.map
      (fun (file, file_warnings) ->
        incr processed;
        let root_path = Fpath.v root_dir in
        let display_path =
          match Fpath.relativize ~root:root_path (Fpath.v file) with
          | Some rel -> Fpath.to_string rel
          | None -> file
        in
        Progress.update progress ~current:!processed display_path;
        (* Process the file *)
        process_file_warnings ~cache ~root_dir ~file file_warnings)
      by_file
  in
  Progress.clear progress;
  (* Calculate total removals *)
  collect_results results
