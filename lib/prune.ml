(* Main prune library - public interface and orchestration *)

open Removal
open Result.Syntax
module Log = (val Logs.src_log (Logs.Src.create "prune") : Logs.LOG)
include Types
(* Re-export core types *)

module Doctor = Doctor
module Show = Show
module Output = Output

(* Error helper functions *)
let err fmt = Fmt.kstr (fun e -> Error (`Msg e)) fmt

let pp_build_error ppf ctx =
  match last_build_result ctx with
  | None -> Fmt.pf ppf "No build output available"
  | Some result -> Fmt.pf ppf "%s" result.output

let err_build_failed ctx = err "Build failed:@.%a" pp_build_error ctx
let err_build_no_info () = err "Build failed with no error information"
let err_build_error ctx = Error (`Build_error ctx)

(* {2 User interaction} *)

(* Ask user for confirmation, defaulting to 'no' if not in a TTY *)
let ask_confirmation prompt =
  if System.is_tty () then (
    Fmt.pr "%s [y/N]: %!" prompt;
    try
      let response = read_line () in
      String.lowercase_ascii (String.trim response) = "y"
    with End_of_file -> false (* Handle Ctrl+D *))
  else (
    (* Not in TTY - default to 'no' *)
    Fmt.pr "%s [y/N]: n (not a tty)@." prompt;
    false)

(* Ask user for confirmation to remove exports *)
let confirm_removal () =
  ask_confirmation "@.Do you want to remove these unused exports?"

(* {2 Reporting functions} *)

(* Get relative path for display *)
let relative_path root_dir file =
  let root_path = Fpath.v root_dir in
  let file_path = Fpath.v file in
  match Fpath.relativize ~root:root_path file_path with
  | Some rel -> Fpath.to_string rel
  | None -> file

(* Count total symbols in unused_by_file list *)
let count_total_symbols unused_by_file =
  List.fold_left
    (fun acc (_, symbols) -> acc + List.length symbols)
    0 unused_by_file

(* Compare symbol_info by line number *)
let compare_symbol_info (a : symbol_info) (b : symbol_info) =
  compare a.location.start_line b.location.start_line

(* Display unused or test-only exports in a formatted report *)
let display_exports ?(label = "unused") ?(no_exports_msg = "")
    ?(show_count = true) occurrences_by_file =
  Log.debug (fun m ->
      m "display_exports (%s): %d files" label (List.length occurrences_by_file));

  match occurrences_by_file with
  | [] -> if no_exports_msg <> "" then Fmt.pr "%s" no_exports_msg
  | _ ->
      (* Sort files and print each export *)
      let sorted_files =
        List.sort (fun (f1, _) (f2, _) -> compare f1 f2) occurrences_by_file
      in
      let total_count =
        List.fold_left
          (fun count (_file, occs) ->
            let sorted_occs =
              List.sort (fun a b -> compare_symbol_info a.symbol b.symbol) occs
            in
            List.iter
              (fun (occ : occurrence_info) ->
                Fmt.pr "%a: %s %s %s@." pp_location occ.symbol.location label
                  (string_of_symbol_kind occ.symbol.kind)
                  occ.symbol.name)
              sorted_occs;
            count + List.length occs)
          0 sorted_files
      in
      if show_count then Fmt.pr "Found %d %s exports@." total_count label

(* Perform actual removal of unused exports *)
let perform_unused_exports_removal ~cache root_dir unused_by_file =
  let total = count_total_symbols unused_by_file in
  Fmt.pr "Removing %d unused exports...@." total;

  let results =
    List.map
      (fun (file, symbols) ->
        let relative_file = relative_path root_dir file in
        match remove_unused_exports ~cache root_dir file symbols with
        | Ok () ->
            Fmt.pr "✓ %s@." relative_file;
            Ok ()
        | Error e ->
            Fmt.pr "✗ %s: %a@." relative_file pp_error e;
            Error e)
      unused_by_file
  in

  (* Return the first error if any *)
  let errors =
    List.filter_map (function Error e -> Some e | Ok () -> None) results
  in
  match errors with [] -> Ok () | e :: _ -> Error e

(* {2 Public interface functions} *)

(* Helper function to build project and handle errors *)
let with_built_project ?(ctx = empty_context) root_dir f =
  match System.build_project_and_index root_dir ctx with
  | Ok () -> f ctx
  | Error (`Build_failed ctx) -> (
      match System.classify_build_error ctx with
      | No_error -> err_build_no_info ()
      | Fixable_errors _ -> err_build_failed ctx
      | Other_errors _output ->
          (* Return error with context for main.ml to handle *)
          err_build_error ctx)

(* Helper to print summary *)
let print_iteration_summary ~cache iteration total_mli total_ml =
  let lines_removed = Cache.count_lines_removed cache in
  let stats =
    {
      mli_exports_removed = total_mli;
      ml_implementations_removed = total_ml;
      iterations = (if total_mli = 0 && total_ml = 0 then 0 else iteration - 1);
      lines_removed;
    }
  in
  if iteration = 1 && total_mli = 0 && total_ml = 0 then (
    Log.info (fun m -> m "Analysis complete: no unused code found");
    Fmt.pr "  ";
    Output.success "✓ No unused code found")
  else (
    Log.info (fun m ->
        m "Iterative analysis complete after %d iterations" (iteration - 1));
    Output.success "✓ No more unused code found";
    Fmt.pr "@.%a@." pp_stats stats);
  stats

(* Convert occurrence info to symbol info for removal *)
let extract_symbols occurrences =
  List.map
    (fun (file, occs) -> (file, List.map (fun occ -> occ.symbol) occs))
    occurrences

(* Process and remove unused exports, returning the count of removed items *)
let process_unused_exports ~cache ~yes ~iteration root_dir all_removable =
  let count = count_total_symbols (extract_symbols all_removable) in

  (* First iteration with confirmation prompt *)
  if (not yes) && iteration = 1 then (
    Fmt.pr "@.Found %d unused exports:@." count;
    display_exports all_removable;
    if not (ask_confirmation "Remove unused exports?") then (
      Fmt.pr "Cancelled - no changes made@.";
      Error (`Msg "Cancelled by user"))
    else
      match
        perform_unused_exports_removal ~cache root_dir
          (extract_symbols all_removable)
      with
      | Error e -> Error e
      | Ok () -> Ok count)
  (* Subsequent iterations or --force mode: no prompt *)
    else
    match
      perform_unused_exports_removal ~cache root_dir
        (extract_symbols all_removable)
    with
    | Error e -> Error e
    | Ok () -> Ok count

(* Find and remove unused exports from .mli files *)
let and_remove_exports ~cache ~yes ~exclude_dirs ~public_files ~iteration
    root_dir mli_files =
  (* Build first to ensure accurate usage information *)
  match System.build_project_and_index root_dir empty_context with
  | Error (`Build_failed _) ->
      Ok 0 (* Continue if build fails - we may be able to fix it *)
  | Ok () -> (
      match Analysis.unused_exports ~cache ~exclude_dirs root_dir mli_files with
      | Error e -> Error e
      | Ok (unused_by_file, excluded_only_by_file) ->
          (* Filter out public files from removal *)
          let unused_by_file =
            List.filter
              (fun (f, _) -> not (List.mem f public_files))
              unused_by_file
          in
          let excluded_only_by_file =
            List.filter
              (fun (f, _) -> not (List.mem f public_files))
              excluded_only_by_file
          in
          let all_removable = unused_by_file @ excluded_only_by_file in
          if all_removable = [] then Ok 0
          else
            process_unused_exports ~cache ~yes ~iteration root_dir all_removable
      )

(* Fix warnings in both .ml and .mli files *)
let fix_all_warnings ~cache root_dir warnings =
  let ml_warnings =
    List.filter
      (fun (w : warning_info) -> String.ends_with ~suffix:".ml" w.location.file)
      warnings
  in

  let mli_warnings =
    List.filter
      (fun (w : warning_info) ->
        String.ends_with ~suffix:".mli" w.location.file)
      warnings
  in

  (* Fix .ml warnings first *)
  match
    if ml_warnings = [] then Ok 0
    else remove_warnings ~cache root_dir ml_warnings
  with
  | Error e -> Error e
  | Ok ml_count -> (
      (* Then fix .mli warnings *)
      match
        if mli_warnings = [] then Ok 0
        else remove_warnings ~cache root_dir mli_warnings
      with
      | Error e -> Error e
      | Ok mli_count ->
          let total = ml_count + mli_count in
          if total > 0 then
            Fmt.pr "  Fixed %d error%s@." total (if total = 1 then "" else "s");
          Ok total)

(* Handle clean build after removing exports *)
let handle_clean_build ~cache iteration total_mli total_ml mli_changes loop =
  if mli_changes = 0 then
    let stats = print_iteration_summary ~cache iteration total_mli total_ml in
    Ok stats
  else
    (* Continue with next iteration *)
    loop (iteration + 1) (total_mli + mli_changes) total_ml

(* Handle build failure and try to fix warnings *)
let handle_build_failure ~cache root_dir iteration total_mli total_ml
    mli_changes loop ctx =
  match System.classify_build_error ctx with
  | No_error -> err_build_no_info ()
  | Other_errors _ -> err_build_error ctx
  | Fixable_errors warnings -> (
      (* Fix warnings and continue *)
      match fix_all_warnings ~cache root_dir warnings with
      | Error e -> Error e
      | Ok warning_count ->
          if warning_count = 0 && mli_changes = 0 then
            (* No progress made - we're done *)
            let stats =
              print_iteration_summary ~cache iteration total_mli total_ml
            in
            Ok stats
          else
            (* Made progress - continue *)
            loop (iteration + 1) (total_mli + mli_changes)
              (total_ml + warning_count))

(* Main iterative analysis loop *)
let iterative_analysis ~cache ~yes ~exclude_dirs ~public_files root_dir
    mli_files =
  Fmt.pr "@.";

  let rec loop iteration total_mli total_ml : (stats, error) result =
    (* Show progress *)
    if iteration > 1 then Fmt.pr "@.";
    Output.section "Iteration %d:" iteration;

    (* Remove unused exports *)
    match
      and_remove_exports ~cache ~yes ~exclude_dirs ~public_files ~iteration
        root_dir mli_files
    with
    | Error (`Msg "Cancelled by user") -> Error (`Msg "Cancelled by user")
    | Error e -> Error e
    | Ok mli_changes -> (
        (* Build and check for warnings *)
        match System.build_project_and_index root_dir empty_context with
        | Ok () ->
            handle_clean_build ~cache iteration total_mli total_ml mli_changes
              loop
        | Error (`Build_failed ctx) ->
            handle_build_failure ~cache root_dir iteration total_mli total_ml
              mli_changes loop ctx)
  in

  loop 1 0 0

type mode = [ `Dry_run | `Single_pass | `Iterative ]

(* Unified analyze function that handles all modes *)
(* Display dry run results *)
let display_dry_run_results ~unused_in_regular ~excluded_in_regular
    ~unused_in_public ~excluded_in_public =
  (* Display unused exports in regular files *)
  if List.length unused_in_regular > 0 then display_exports unused_in_regular;

  (* Display excluded-only exports in regular files *)
  if List.length excluded_in_regular > 0 then (
    Output.warning "Some exports are only used in excluded directories";
    display_exports ~label:"used only in excluded dirs" excluded_in_regular);

  (* Display info about public files if they have unused exports *)
  let public_unused = unused_in_public @ excluded_in_public in
  if List.length public_unused > 0 then (
    Fmt.pr "@.";
    Output.section "Unused exports in public files (will not be removed):";
    display_exports ~label:"unused (public)" ~show_count:false public_unused);

  let removable = unused_in_regular @ excluded_in_regular in
  let total = count_total_symbols removable in
  if total = 0 && List.length public_unused > 0 then
    Fmt.pr "No removable exports (only public files have unused exports)@.";
  total

(* Handle dry run mode *)
let analyze_dry_run ~cache ~exclude_dirs ~public_files root_dir mli_files =
  with_built_project root_dir (fun _ctx ->
      let* unused_by_file, excluded_only_by_file =
        Analysis.unused_exports ~cache ~exclude_dirs root_dir mli_files
      in
      (* Separate public and non-public files *)
      let unused_in_public, unused_in_regular =
        List.partition (fun (f, _) -> List.mem f public_files) unused_by_file
      in
      let excluded_in_public, excluded_in_regular =
        List.partition
          (fun (f, _) -> List.mem f public_files)
          excluded_only_by_file
      in

      match
        ( unused_in_regular,
          excluded_in_regular,
          unused_in_public,
          excluded_in_public )
      with
      | [], [], [], [] ->
          Fmt.pr "  ";
          Output.success "No unused exports found!";
          Ok empty_stats
      | _ ->
          let total =
            display_dry_run_results ~unused_in_regular ~excluded_in_regular
              ~unused_in_public ~excluded_in_public
          in
          Ok { empty_stats with mli_exports_removed = total })

(* Handle single pass mode *)
let analyze_single_pass ~cache ~yes ~exclude_dirs ~public_files root_dir
    mli_files =
  with_built_project root_dir (fun _ctx ->
      let* unused_by_file, excluded_only_by_file =
        Analysis.unused_exports ~cache ~exclude_dirs root_dir mli_files
      in
      (* Filter out public files from removal *)
      let unused_by_file =
        List.filter (fun (f, _) -> not (List.mem f public_files)) unused_by_file
      in
      let excluded_only_by_file =
        List.filter
          (fun (f, _) -> not (List.mem f public_files))
          excluded_only_by_file
      in
      (* Combine unused and excluded-only exports for removal *)
      let all_removable = unused_by_file @ excluded_only_by_file in
      match all_removable with
      | [] ->
          Fmt.pr "  ";
          Output.success "No unused exports found!";
          Ok empty_stats
      | _ ->
          (* Display both types of exports *)
          if List.length unused_by_file > 0 then
            display_exports ~no_exports_msg:"" unused_by_file;
          if List.length excluded_only_by_file > 0 then
            display_exports ~label:"used only in excluded dirs"
              excluded_only_by_file;
          if yes || confirm_removal () then
            (* Convert to symbol_info for removal *)
            let symbol_by_file =
              List.map
                (fun (file, occs) ->
                  (file, List.map (fun occ -> occ.symbol) occs))
                all_removable
            in
            let* () =
              perform_unused_exports_removal ~cache root_dir symbol_by_file
            in
            let total = count_total_symbols symbol_by_file in
            let lines_removed = Cache.count_lines_removed cache in
            Ok
              {
                empty_stats with
                mli_exports_removed = total;
                lines_removed;
                iterations = 1;
              }
          else (
            Fmt.pr "Aborted - no files were modified.@.";
            Ok empty_stats))

let analyze ?(yes = false) ?(exclude_dirs = []) ?(public_files = []) mode
    root_dir mli_files =
  (* Report public files if any *)
  (if public_files <> [] then
     let public_in_analysis =
       List.filter (fun f -> List.mem f mli_files) public_files
     in
     if public_in_analysis <> [] then (
       Output.section
         "Marking %d file(s) as public APIs (will not be modified):"
         (List.length public_in_analysis);
       List.iter (fun f -> Fmt.pr "  - %s@." f) public_in_analysis;
       Fmt.pr "@."));

  let cache = Cache.v () in
  let result =
    match mode with
    | `Dry_run ->
        analyze_dry_run ~cache ~exclude_dirs ~public_files root_dir mli_files
    | `Single_pass ->
        analyze_single_pass ~cache ~yes ~exclude_dirs ~public_files root_dir
          mli_files
    | `Iterative ->
        iterative_analysis ~cache ~yes ~exclude_dirs ~public_files root_dir
          mli_files
  in
  (* Clear the file cache after processing *)
  Cache.clear cache;
  result

module Removal = Removal
module Cache = Cache
(* Internal modules exposed for testing *)

module System = System
(* Internal system module exposed for main.ml *)

module Analysis = Analysis
(* Internal analysis module exposed for testing *)

module Module_alias = Module_alias
(* Internal module_alias module exposed for testing *)

module Warning = Warning
(* Internal warning module exposed for testing *)

module Locate = Locate
(* Internal locate module exposed for testing *)
