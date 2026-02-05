(* System utilities for prune - TTY detection, dune operations, and project
   validation *)

open Bos
module Log = (val Logs.src_log (Logs.Src.create "prune.system") : Logs.LOG)

(* Error helper functions *)
let err fmt = Fmt.kstr (fun e -> Error (`Msg e)) fmt

let err_no_dune_project root_dir =
  err "No dune-project file found in %s" root_dir

let err_version_parse version = err "Could not parse OCaml version: %s" version

(* {2 TTY and environment detection} *)

let is_tty () = try Unix.isatty Unix.stdout with Unix.Unix_error _ -> false

(* {2 Dune version checking} *)

let dune_version () =
  match OS.Cmd.run_out Cmd.(v "dune" % "--version") |> OS.Cmd.out_string with
  | Ok (version_str, _) -> Some (String.trim version_str)
  | Error _ -> None

let should_skip_dune_operations =
  lazy
    (match Sys.getenv_opt "INSIDE_DUNE" with
    | None -> false
    | Some _ -> (
        match dune_version () with
        | Some "3.19.0" -> true
        | Some version ->
            Log.debug (fun m ->
                m "Dune version %s detected, safe to run nested dune commands"
                  version);
            false
        | None ->
            Log.warn (fun m ->
                m
                  "Could not detect dune version, being conservative and \
                   skipping nested dune");
            true))

(* {2 OCaml version checking} *)

let ocaml_version () =
  match OS.Cmd.run_out Cmd.(v "ocaml" % "-version") |> OS.Cmd.out_string with
  | Ok (version_str, _) -> (
      let version_str = String.trim version_str in
      match String.split_on_char ' ' version_str with
      | _ :: _ :: _ :: "version" :: version :: _ -> Some version
      | _ -> None)
  | Error _ -> None

let parse_version version_str =
  let extract_number s =
    match String.split_on_char '+' s with
    | num :: _ -> (
        match String.split_on_char '-' num with num :: _ -> num | [] -> num)
    | [] -> s
  in
  match String.split_on_char '.' version_str with
  | major :: minor :: patch :: _ -> (
      try
        Some
          ( int_of_string major,
            int_of_string minor,
            int_of_string (extract_number patch) )
      with Failure _ -> None)
  | [ major; minor ] -> (
      try Some (int_of_string major, int_of_string minor, 0)
      with Failure _ -> None)
  | _ -> None

let check_ocaml_version () =
  match ocaml_version () with
  | None -> Error (`Msg "Could not determine OCaml compiler version")
  | Some version_str -> (
      match parse_version version_str with
      | None -> err_version_parse version_str
      | Some (major, minor, _patch) ->
          if major > 5 || (major = 5 && minor >= 3) then Ok ()
          else
            Error
              (`Msg
                 (Fmt.str
                    "OCaml compiler version %s is below the minimum required \
                     version 5.3.0. Please upgrade your OCaml compiler to use \
                     prune."
                    version_str)))

(* {2 Project validation} *)

let validate_dune_project root_dir =
  let root_path = Fpath.v root_dir in
  let dune_project = Fpath.(root_path / "dune-project") in
  match OS.File.exists dune_project with
  | Ok false | Error _ -> err_no_dune_project root_dir
  | Ok true -> Ok ()

(* {2 Dune build operations} *)

let run_build_command _cmd_desc build_cmd =
  Log.debug (fun m -> m "Running: %s" (Cmd.to_string build_cmd));
  match
    OS.Cmd.run_out ~err:OS.Cmd.err_run_out build_cmd |> OS.Cmd.out_string
  with
  | Error (`Msg err) ->
      { Types.success = false; output = err; exit_code = 1; warnings = [] }
  | Ok (output, (_, status)) ->
      let exit_code =
        match status with `Exited n -> n | `Signaled n -> 128 + n
      in
      { Types.success = exit_code = 0; output; exit_code; warnings = [] }

let run_single_build root_dir ctx =
  Log.info (fun m -> m "Running build");
  let build_cmd =
    Cmd.(v "dune" % "build" % "--root" % root_dir % "@all" % "@ocaml-index")
  in
  let result = run_build_command "build" build_cmd in
  let ctx = Types.update_build_result ctx result in
  let warnings = Warning.parse result.output in
  let ctx = Types.update_build_result ctx { result with warnings } in
  (ctx, warnings)

let build_project_and_index root_dir ctx =
  if Lazy.force should_skip_dune_operations then (
    Log.info (fun m ->
        m
          "Running inside dune with problematic version - skipping index build \
           to avoid deadlock");
    Log.warn (fun m ->
        m "Cross-module detection may be limited without pre-built index");
    Ok ())
  else
    let ctx, _warnings = run_single_build root_dir ctx in
    match Types.last_build_result ctx with
    | Some result when result.success ->
        Log.debug (fun m -> m "Build completed successfully");
        Ok ()
    | _ -> Error (`Build_failed ctx)

let is_fixable_warning warning_type =
  match warning_type with
  | Types.Signature_mismatch | Types.Unbound_field -> true
  | Types.Unused_value -> true
  | Types.Unused_type -> true
  | Types.Unused_open -> true
  | Types.Unused_constructor -> true
  | Types.Unused_field -> true
  | Types.Unnecessary_mutable -> true
  | _ -> false

let extract_fixable_errors result =
  let parsed_errors : Types.warning_info list = result.Types.warnings in
  let fixable_errors =
    List.filter (fun w -> is_fixable_warning w.Types.warning_type) parsed_errors
  in
  Log.debug (fun m -> m "Found %d fixable errors" (List.length fixable_errors));
  fixable_errors

let output_excerpt result =
  if String.length result.Types.output > 1000 then
    String.sub result.Types.output 0 1000 ^ "\n[... output truncated ...]"
  else result.Types.output

let classify_build_error ctx =
  match Types.last_build_result ctx with
  | None -> Types.Other_errors "No build result available"
  | Some result when result.success -> Types.No_error
  | Some result ->
      Log.debug (fun m -> m "Build failed with output:\n%s" result.output);
      let fixable_errors = extract_fixable_errors result in
      if fixable_errors <> [] then Types.Fixable_errors fixable_errors
      else
        let output_excerpt = output_excerpt result in
        Types.Other_errors output_excerpt

let count_all_errors output =
  let lines = String.split_on_char '\n' output in
  List.fold_left
    (fun count line ->
      let line = String.trim line in
      if String.length line > 6 && String.sub line 0 6 = "Error:" then count + 1
      else if
        Re.execp
          (Re.compile
             (Re.seq [ Re.str "characters"; Re.rep Re.any; Re.str ": Error" ]))
          line
      then count + 1
      else count)
    0 lines

let display_failure_and_exit ctx =
  let total_error_count =
    match Types.last_build_result ctx with
    | Some result -> count_all_errors result.output
    | None -> 0
  in
  Fmt.pr "%a with %d %s - full output:@."
    Fmt.(styled (`Fg `Red) string)
    "Build failed" total_error_count
    (if total_error_count = 1 then "error" else "errors");
  let pp_build_error ppf ctx =
    match Types.last_build_result ctx with
    | None -> Fmt.pf ppf "No build output available"
    | Some result -> Fmt.pf ppf "%s" result.output
  in
  Fmt.pr "%a@." pp_build_error ctx;
  let exit_code =
    match Types.last_build_result ctx with
    | Some result -> result.exit_code
    | None -> 1
  in
  exit exit_code
