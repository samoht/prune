(* Occurrence checking and classification for symbols *)

open Types
module Log = (val Logs.src_log (Logs.Src.create "prune.occurrence") : Logs.LOG)

(* {2 Merlin type conversions} *)

let convert_occurrence ~root_dir (occ : Merlin.occurrence) : location =
  let file = occ.loc.file in
  let file =
    let root_dir_fpath = Fpath.v root_dir in
    let path_fpath = Fpath.v file in
    match Fpath.relativize ~root:root_dir_fpath path_fpath with
    | None -> file
    | Some rel ->
        let rel_str = Fpath.to_string rel in
        if String.length rel_str >= 2 && String.sub rel_str 0 2 = "./" then
          String.sub rel_str 2 (String.length rel_str - 2)
        else rel_str
  in
  Types.location ~line:occ.loc.start.line ~end_line:occ.loc.end_.line
    ~start_col:occ.loc.start.col ~end_col:occ.loc.end_.col file

(* Find the column position of an identifier in a type declaration *)
let type_identifier_column line_content start_col =
  (* After "type", skip whitespace and type parameters to find the identifier *)
  let len = String.length line_content in
  let rec skip_whitespace i =
    if i >= len then i
    else if line_content.[i] = ' ' || line_content.[i] = '\t' then
      skip_whitespace (i + 1)
    else i
  in

  let rec skip_type_params i paren_depth =
    if i >= len then i
    else
      match line_content.[i] with
      | '(' -> skip_type_params (i + 1) (paren_depth + 1)
      | ')' -> skip_type_params (i + 1) (paren_depth - 1)
      | (' ' | '\t') when paren_depth = 0 ->
          (* Found space outside parens, we're past type params *)
          skip_whitespace (i + 1)
      | '\'' when paren_depth = 0 ->
          (* Type variable like 'a, skip it *)
          let i = i + 1 in
          let rec skip_var j =
            if j >= len then j
            else
              match line_content.[j] with
              | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' -> skip_var (j + 1)
              | _ -> j
          in
          skip_type_params (skip_var i) 0
      | _ when paren_depth > 0 ->
          (* Inside parens, skip everything *)
          skip_type_params (i + 1) paren_depth
      | ('a' .. 'z' | 'A' .. 'Z' | '_') when paren_depth = 0 ->
          (* Found the start of an identifier *)
          i
      | _ -> skip_type_params (i + 1) paren_depth
  in

  (* Start after "type " *)
  let start = start_col + 5 in
  if start < len then skip_type_params (skip_whitespace start) 0 else start

(* Get the column position of the identifier based on symbol kind *)
let identifier_column ~cache (symbol : symbol_info) =
  (* For .mli files, identifiers start after the keyword *)
  let is_mli =
    let len = String.length symbol.location.file in
    len >= 4 && String.sub symbol.location.file (len - 4) 4 = ".mli"
  in
  let col = symbol.location.start_col in
  if is_mli then
    match symbol.kind with
    | Value -> col + 4 (* "val " = 4 chars *)
    | Type -> (
        (* For types, we need to handle type parameters *)
        match
          Cache.line cache symbol.location.file symbol.location.start_line
        with
        | Some line_content -> type_identifier_column line_content col
        | None -> col + 5 (* Fallback to simple offset *))
    | Module -> col + 7 (* "module " = 7 chars *)
    | Constructor -> col + 10 (* "exception " = 10 chars *)
    | Field -> col (* Fields don't have a keyword prefix *)
  else col (* For .ml files, use position as-is *)

(* Check if a file or directory is in the excluded list *)
let is_excluded_file exclude_dirs file_path =
  match exclude_dirs with
  | [] -> false
  | dirs ->
      let fpath = Fpath.v file_path in
      (* Check if file is in any excluded directory *)
      List.exists
        (fun dir ->
          (* Normalize the excluded directory path *)
          let dir_fpath = Fpath.normalize (Fpath.v dir) in
          (* Check if path has dir as a prefix segment *)
          Fpath.is_prefix dir_fpath fpath
          ||
          (* Check if any parent directory has the excluded dir name *)
          let rec check_parents p depth =
            (* Safety check: limit recursion depth *)
            if depth > 100 then false
            else if
              Fpath.is_root p
              || Fpath.equal p (Fpath.v ".")
              || Fpath.equal p (Fpath.v "..")
            then false
            else
              let basename = Fpath.basename p in
              if String.equal basename dir then true
              else
                let parent = Fpath.parent p in
                (* Check if we've reached a fixed point *)
                if Fpath.equal parent p then false
                else check_parents parent (depth + 1)
          in
          check_parents fpath 0)
        dirs

(* Helper to handle modules and constructors that rely on build warnings *)
let handle_module_or_constructor (symbol : symbol_info) =
  Log.info (fun m ->
      m "Skipping merlin occurrences for %s %s (relying on build warnings)"
        (string_of_symbol_kind symbol.kind)
        symbol.name);

  {
    symbol;
    occurrences = -1;
    (* Mark as -1 to indicate merlin check was skipped *)
    locations = [];
    usage_class = Unknown;
    (* Cannot determine via occurrences *)
  }

(* Helper to query merlin for occurrences *)
let query_merlin ~cache root_dir symbol =
  let identifier_col = identifier_column ~cache symbol in
  Log.info (fun m ->
      m "Checking occurrences for %s at %a (adjusted to %d:%d)" symbol.name
        pp_location symbol.location symbol.location.start_line identifier_col);
  let m = Merlin.create ~backend:Lib ~root_dir () in
  let result =
    Merlin.occurrences m ~file:symbol.location.file
      ~line:symbol.location.start_line ~col:identifier_col ~scope:Project
  in
  Merlin.close m;
  match result with
  | Error e ->
      Log.debug (fun f ->
          f "Merlin occurrences failed for %s: %s" symbol.name e);
      (0, [])
  | Ok occ_result ->
      let locations =
        List.map (convert_occurrence ~root_dir) occ_result.occurrences
      in
      (List.length locations, locations)

(* Get base module name from file path *)
let module_base file =
  let basename = Filename.basename file in
  try Filename.chop_extension basename with Invalid_argument _ -> basename

(* Get the full module path (directory + module name) to distinguish between
   modules with the same name in different directories *)
let module_path file =
  let dir = Filename.dirname file in
  let base = module_base file in
  Filename.concat dir base

(* Count occurrences by location type *)
type counts = {
  in_defining_mli : int;
  in_defining_ml : int;
  external_uses : location list;
}

let count_occurrences_by_location defining_module_path locations =
  let counts =
    ref { in_defining_mli = 0; in_defining_ml = 0; external_uses = [] }
  in

  List.iter
    (fun (loc : location) ->
      Log.debug (fun m ->
          m "    Occurrence at %s:%d:%d" loc.file loc.start_line loc.start_col);
      let module_path = module_path loc.file in
      Log.debug (fun m ->
          m "      Module path: %s, defining module path: %s, equal: %b"
            module_path defining_module_path
            (module_path = defining_module_path));
      if module_path = defining_module_path then (
        if Filename.check_suffix loc.file ".mli" then (
          counts :=
            { !counts with in_defining_mli = !counts.in_defining_mli + 1 };
          Log.debug (fun m -> m "      -> Counted as in_defining_mli"))
        else if Filename.check_suffix loc.file ".ml" then (
          counts := { !counts with in_defining_ml = !counts.in_defining_ml + 1 };
          Log.debug (fun m -> m "      -> Counted as in_defining_ml")))
      else (
        counts := { !counts with external_uses = loc :: !counts.external_uses };
        Log.debug (fun m -> m "      -> Counted as external use")))
    locations;
  !counts

(* Check if symbol appears to be a re-export *)
let is_likely_reexport locations occurrence_count =
  let mli_count =
    List.fold_left
      (fun acc (loc : location) ->
        if Filename.check_suffix loc.file ".mli" then acc + 1 else acc)
      0 locations
  in
  mli_count > 1 && occurrence_count <= mli_count + 1

(* Check if all external uses are in excluded directories *)
let all_external_uses_excluded exclude_dirs external_locs =
  not
    (List.exists
       (fun (loc : location) ->
         let is_excluded = is_excluded_file exclude_dirs loc.file in
         Log.debug (fun m ->
             m "    Checking if %s is excluded: %b (exclude_dirs: %s)" loc.file
               is_excluded
               (String.concat ", " exclude_dirs));
         not is_excluded)
       external_locs)

(* Classify symbol with no external uses *)
let classify_no_external_uses (sym : symbol_info) counts =
  Log.debug (fun m ->
      m "  No external uses for %s, in_defining_mli=%d, in_defining_ml=%d"
        sym.name counts.in_defining_mli counts.in_defining_ml);
  if counts.in_defining_mli = 1 then (
    Log.debug (fun m -> m "  -> Marking %s as Unused" sym.name);
    Unused)
  else (
    Log.debug (fun m -> m "  -> Marking %s as Used" sym.name);
    Used)

(* Classify symbol with external uses *)
let classify_with_external_uses exclude_dirs (sym : symbol_info) external_locs =
  Log.debug (fun m ->
      m "  %s has %d external uses" sym.name (List.length external_locs));
  if all_external_uses_excluded exclude_dirs external_locs then (
    Log.debug (fun m ->
        m
          "  -> All external uses are excluded, marking as \
           Used_only_in_excluded");
    Used_only_in_excluded)
  else (
    Log.debug (fun m ->
        m "  -> Has non-excluded external uses, marking as Used");
    Used)

(* Classify usage for types, values, and fields *)
let classify_type_value_field exclude_dirs (sym : symbol_info) occurrence_count
    locations =
  Log.debug (fun m ->
      m "  Analyzing %d occurrences for %s %s" occurrence_count
        (string_of_symbol_kind sym.kind)
        sym.name);

  let defining_module_path = module_path sym.location.file in
  let counts = count_occurrences_by_location defining_module_path locations in

  Log.debug (fun m ->
      m "  Symbol %s: mli_in_defining=%d, external=%d" sym.name
        counts.in_defining_mli
        (List.length counts.external_uses));

  (* Check for re-export pattern *)
  if is_likely_reexport locations occurrence_count then (
    Log.debug (fun m ->
        m
          "Symbol %s appears in multiple .mli files with only %d occurrences, \
           likely a re-export"
          sym.name occurrence_count);
    Used)
  else
    (* Determine usage classification *)
    match counts.external_uses with
    | [] -> classify_no_external_uses sym counts
    | external_locs ->
        classify_with_external_uses exclude_dirs sym external_locs

(* Classify how a symbol is used based on its occurrences *)
let classify_usage exclude_dirs (symbol : symbol_info) occurrence_count
    locations =
  (* Special handling for different symbol kinds *)
  match symbol.kind with
  | Module | Constructor ->
      (* Modules and constructors may not have all their uses tracked by merlin
         E.g., when used in patterns or type annotations -1 means merlin check
         was skipped, so we can't determine usage *)
      if occurrence_count = -1 then Unknown
      else if occurrence_count > 1 then Used
      else Unused
  | Type | Value | Field ->
      (* For other symbols, analyze occurrence locations *)
      classify_type_value_field exclude_dirs symbol occurrence_count locations

(* Check a single symbol *)
let check_single ~cache exclude_dirs root_dir (symbol : symbol_info) =
  (* For modules and exceptions, skip merlin occurrences *)
  (* Merlin's occurrence detection doesn't work reliably for:
     - Exceptions: often returns 0 even when used
     - Modules: need special handling for children
     For now, mark as potentially unused and let build warnings decide *)
  match symbol.kind with
  | Module | Constructor -> handle_module_or_constructor symbol
  | _ ->
      (* For values and types, use merlin occurrences *)
      let occurrence_count, locations = query_merlin ~cache root_dir symbol in

      Log.debug (fun m ->
          m "Extracted from merlin for %s: count=%d, locations=[%s]" symbol.name
            occurrence_count
            (locations
            |> List.map (fun loc -> Fmt.str "%a" pp_location loc)
            |> String.concat "; "));

      let usage_class =
        classify_usage exclude_dirs symbol occurrence_count locations
      in

      Log.debug (fun m ->
          m "Symbol %s: %d occurrences, usage=%a, locations=%s" symbol.name
            occurrence_count pp_usage_classification usage_class
            (String.concat ", "
               (List.map (fun loc -> Fmt.str "%a" pp_location loc) locations)));

      (* Debug: print occurrence mapping summary *)
      Log.info (fun m ->
          m "OCCURRENCE MAPPING: %s@%a -> %d occurrences" symbol.name
            pp_location symbol.location occurrence_count);

      { symbol; occurrences = occurrence_count; locations; usage_class }

(* Check occurrences for a list of symbols using merlin *)
let check_bulk ~cache exclude_dirs root_dir (symbols : symbol_info list) =
  let total = List.length symbols in
  let processed = ref 0 in

  if total > 0 then
    Log.info (fun m -> m "Checking occurrences for %d symbols" total);

  let progress = Progress.v ~total in
  let results =
    List.map
      (fun (symbol : symbol_info) ->
        incr processed;
        let module_name =
          let basename = Filename.basename symbol.location.file in
          let name =
            try Filename.chop_extension basename
            with Invalid_argument _ -> basename
          in
          String.capitalize_ascii name
        in
        Progress.update progress ~current:!processed
          (Fmt.str "Checking symbol: %s.%s" module_name symbol.name);

        let result = check_single ~cache exclude_dirs root_dir symbol in
        result)
      symbols
  in
  Progress.clear progress;
  results
