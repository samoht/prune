(* Symbol discovery and analysis orchestration for prune *)

open Types
open Rresult
module Log = (val Logs.src_log (Logs.Src.create "prune.analysis") : Logs.LOG)

(* {2 Symbol extraction} *)

(* Helper to create a symbol with its children *)
let rec symbol_with_children ~cache item =
  let main_symbol =
    { name = item.name; kind = item.kind; location = item.location }
  in
  let child_symbols =
    match item.children with
    | None -> []
    | Some children -> List.concat_map (outline_item_to_symbol ~cache) children
  in
  main_symbol :: child_symbols

(* Convert a single outline item to a symbol_info *)
and outline_item_to_symbol ~cache (item : outline_item) =
  match item.kind with
  | Module -> (
      (* For modules, check if it's a module alias and skip if so *)
      match Cache.load cache item.location.file with
      | Error _ -> symbol_with_children ~cache item
      | Ok () -> (
          match Cache.file_content cache item.location.file with
          | None -> symbol_with_children ~cache item
          | Some content ->
              if
                Module_alias.is_module_alias ~cache item.location.file item.kind
                  item.location content
              then (
                Log.debug (fun m ->
                    m "Skipping module alias: %s at %a" item.name pp_location
                      item.location);
                [])
              else symbol_with_children ~cache item))
  | _ -> symbol_with_children ~cache item

(* {2 Symbol discovery} *)

(* Get all exported symbols from a single .mli file *)
let file_symbols ~cache root_dir file_str =
  let merlin_result = System.call_merlin root_dir file_str "outline" in
  match outline_response_of_json ~file:file_str merlin_result with
  | Error e ->
      Log.warn (fun m ->
          m "Failed to parse outline for %s: %a" file_str pp_error e);
      []
  | Ok outline_items ->
      let symbols =
        List.concat_map (outline_item_to_symbol ~cache) outline_items
      in
      (* Debug: print outline summary *)
      Log.info (fun m ->
          m "Outline summary for %s: found %d symbols" file_str
            (List.length symbols));
      List.iteri
        (fun i (symbol : symbol_info) ->
          Log.debug (fun m ->
              m "  [%d] %s (%s) at %a" (i + 1) symbol.name
                (string_of_symbol_kind symbol.kind)
                pp_location symbol.location))
        symbols;
      symbols

(* {2 Main analysis orchestration} *)

(* Filter symbols to only those we care about *)
let filter_relevant_symbols all_symbols =
  let relevant_symbols =
    List.filter
      (fun (s : symbol_info) ->
        match s.kind with
        | Value | Type | Constructor | Module -> true
        | Field -> false)
      all_symbols
  in
  if List.length relevant_symbols > 0 then
    Log.info (fun m ->
        m
          "Filtering to %d relevant symbols (values, types, exceptions, \
           modules)"
          (List.length relevant_symbols));
  relevant_symbols

(* Group occurrence info by file, preserving usage classification *)
let group_occurrences_by_file occurrence_infos =
  let by_file =
    List.fold_left
      (fun acc occ ->
        let file = occ.symbol.location.file in
        let existing = try List.assoc file acc with Not_found -> [] in
        (file, occ :: existing) :: List.remove_assoc file acc)
      [] occurrence_infos
  in
  if List.length by_file > 0 then
    Log.info (fun m -> m "Grouped into %d files" (List.length by_file));
  by_file

(* Build a recursive check for modules with used children *)
let rec has_used_children all_occurrence_data module_occ =
  match module_occ.symbol.kind with
  | Module ->
      let module_start = module_occ.symbol.location.start_line in
      let module_end =
        match Some module_occ.symbol.location.end_line with
        | Some el -> el
        | None -> module_start
      in

      (* Find all symbols within this module's range *)
      let children =
        List.filter
          (fun occ ->
            occ.symbol.location.file = module_occ.symbol.location.file
            && occ.symbol.location.start_line > module_start
            && occ.symbol.location.start_line <= module_end
            && occ.symbol.name <> module_occ.symbol.name)
          all_occurrence_data
      in

      Log.debug (fun m ->
          m "Module %s has %d children" module_occ.symbol.name
            (List.length children));

      (* Check if any child is either: 1. A used symbol (occurrences > 0), or 2.
         A module that has used children (recursive check) *)
      List.exists
        (fun child ->
          if child.occurrences > 0 then (
            Log.debug (fun m ->
                m "  Child %s is used (%d occurrences)" child.symbol.name
                  child.occurrences);
            true)
          else has_used_children all_occurrence_data child)
        children
  | _ -> false

(* Filter out modules that have any used children *)
let filter_modules_with_used unused_symbols all_occurrence_data =
  if List.length unused_symbols > 0 then
    Log.info (fun m ->
        m "Filtering modules with used children: %d unused symbols to check"
          (List.length unused_symbols));

  (* Filter out modules that have used children *)
  List.filter
    (fun occ ->
      match occ.symbol.kind with
      | Module ->
          let should_keep = not (has_used_children all_occurrence_data occ) in
          Log.debug (fun m ->
              m "Module %s: has_used_children=%b, keeping=%b" occ.symbol.name
                (not should_keep) should_keep);
          should_keep
      | _ -> true (* Keep all non-module symbols in the unused list *))
    unused_symbols

(* Common function to get symbols and their occurrences *)
let symbols_and_occurrences ~cache exclude_dirs root_dir files =
  if List.length files > 0 then
    Log.info (fun m -> m "Analyzing %d files for symbols" (List.length files));

  (* Get exported symbols from all files with progress *)
  let total = List.length files in
  let processed = ref 0 in
  let root_path = Fpath.v root_dir in
  let progress = Progress.v ~total in

  let all_symbols =
    List.fold_left
      (fun acc file ->
        incr processed;
        let display_path =
          match Fpath.relativize ~root:root_path (Fpath.v file) with
          | Some rel -> Fpath.to_string rel
          | None -> file
        in
        Progress.update progress ~current:!processed
          (Fmt.str "Processing file: %s" display_path);

        let symbols = file_symbols ~cache root_dir file in
        symbols @ acc)
      [] files
  in
  Progress.clear progress;

  if List.length all_symbols > 0 then
    Log.info (fun m ->
        m "Found %d total exported symbols" (List.length all_symbols));

  let relevant_symbols = filter_relevant_symbols all_symbols in
  let occurrence_data =
    Occurrence.check_bulk ~cache exclude_dirs root_dir relevant_symbols
  in
  (all_symbols, occurrence_data)

(* Analyze symbols from files and find unused ones *)
(* Find symbols that appear in multiple .mli files *)
let multi_mli_symbols occurrence_data =
  let mli_symbols =
    List.filter
      (fun sym -> Filename.check_suffix sym.symbol.location.file ".mli")
      occurrence_data
  in
  let name_to_files = Hashtbl.create 10 in
  List.iter
    (fun occ ->
      let files =
        try Hashtbl.find name_to_files occ.symbol.name with Not_found -> []
      in
      if not (List.mem occ.symbol.location.file files) then
        Hashtbl.replace name_to_files occ.symbol.name
          (occ.symbol.location.file :: files))
    mli_symbols;

  Hashtbl.fold
    (fun name files acc -> if List.length files > 1 then name :: acc else acc)
    name_to_files []

(* Fix symbols that appear in multiple .mli files by marking them as Used *)
let fix_multi_mli_symbols occurrence_data multi_mli_names =
  if multi_mli_names <> [] then (
    Log.info (fun m ->
        m "Found symbols in multiple .mli files: %s"
          (String.concat ", " multi_mli_names));
    List.map
      (fun occ ->
        if List.mem occ.symbol.name multi_mli_names && occ.usage_class = Unused
        then { occ with usage_class = Used }
        else occ)
      occurrence_data)
  else occurrence_data

(* Filter occurrence data to get unused and excluded-only symbols *)
let categorize_symbols occurrence_data =
  let unused =
    List.filter
      (fun occ ->
        match occ.usage_class with
        | Unused -> true
        | Unknown | Used | Used_only_in_excluded -> false)
      occurrence_data
  in
  let excluded_only =
    List.filter
      (fun occ ->
        match occ.usage_class with Used_only_in_excluded -> true | _ -> false)
      occurrence_data
  in
  (unused, excluded_only)

let analyze_files_for_unused ~cache exclude_dirs root_dir files =
  let _all_symbols, occurrence_data =
    symbols_and_occurrences ~cache exclude_dirs root_dir files
  in

  (* Post-process: if a symbol name appears in multiple .mli files, mark all as
     Used. This handles both re-exports and symbols accessible through module
     aliases. *)
  let multi_mli_names = multi_mli_symbols occurrence_data in

  let occurrence_data_fixed =
    fix_multi_mli_symbols occurrence_data multi_mli_names
  in

  let unused, excluded_only = categorize_symbols occurrence_data_fixed in

  (* Filter out modules that have used children *)
  let filtered_unused = filter_modules_with_used unused occurrence_data_fixed in

  Log.info (fun m -> m "Found %d unused exports" (List.length filtered_unused));
  if List.length excluded_only > 0 then
    Log.info (fun m ->
        m "Found %d exports used only in excluded dirs"
          (List.length excluded_only));

  ( group_occurrences_by_file filtered_unused,
    group_occurrences_by_file excluded_only )

let all_symbol_occurrences ~cache ?(exclude_dirs = []) root_dir files =
  match System.validate_dune_project root_dir with
  | Error (`Msg e) -> Error (`Msg e)
  | Ok () ->
      Log.info (fun m -> m "Getting all symbol occurrences");
      let _all_symbols, occurrence_data =
        symbols_and_occurrences ~cache exclude_dirs root_dir files
      in
      Ok occurrence_data

let unused_exports ~cache ?(exclude_dirs = []) root_dir files =
  match System.validate_dune_project root_dir with
  | Error (`Msg e) -> Error (`Msg e)
  | Ok () ->
      Log.info (fun m -> m "Starting analysis");
      Ok (analyze_files_for_unused ~cache exclude_dirs root_dir files)
