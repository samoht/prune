(* System utilities for prune - TTY detection, dune operations, and merlin
   communication *)

open Bos
open Rresult
module Log = (val Logs.src_log (Logs.Src.create "prune.system") : Logs.LOG)

(* Error helper functions *)
let err fmt = Fmt.kstr (fun e -> Error (`Msg e)) fmt

let err_no_dune_project root_dir =
  err "No dune-project file found in %s" root_dir

(* {2 TTY and environment detection} *)

(* Check if we're running in a TTY (for progress display) *)
let is_tty () = try Unix.isatty Unix.stdout with _ -> false

(* {2 Dune version checking} *)

(* Get dune version *)
let get_dune_version () =
  match OS.Cmd.run_out Cmd.(v "dune" % "--version") |> OS.Cmd.out_string with
  | Ok (version_str, _) -> Some (String.trim version_str)
  | Error _ -> None

(* Lazy computation of whether we should skip dune operations *)
let should_skip_dune_operations =
  lazy
    (match Sys.getenv_opt "INSIDE_DUNE" with
    | None -> false
    | Some _ -> (
        match get_dune_version () with
        | Some "3.19.0" -> true (* Only skip for problematic version *)
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

(* Get OCaml compiler version *)
let get_ocaml_version () =
  match OS.Cmd.run_out Cmd.(v "ocaml" % "-version") |> OS.Cmd.out_string with
  | Ok (version_str, _) -> (
      (* OCaml version output format: "The OCaml toplevel, version X.Y.Z" *)
      let version_str = String.trim version_str in
      match String.split_on_char ' ' version_str with
      | _ :: _ :: _ :: "version" :: version :: _ -> Some version
      | _ -> None)
  | Error _ -> None

(* Parse version string to compare *)
let parse_version version_str =
  (* Extract just the numeric part before any '+' or '-' *)
  let extract_number s =
    match String.split_on_char '+' s with
    | num :: _ -> (
        (* Also handle '-' in case of versions like 5.3.1-dev *)
        match String.split_on_char '-' num with
        | num :: _ -> num
        | [] -> num)
    | [] -> s
  in
  match String.split_on_char '.' version_str with
  | major :: minor :: patch :: _ -> (
      try
        Some
          ( int_of_string major,
            int_of_string minor,
            int_of_string (extract_number patch) )
      with _ -> None)
  | [ major; minor ] -> (
      try Some (int_of_string major, int_of_string minor, 0) with _ -> None)
  | _ -> None

(* Check if OCaml version meets minimum requirements *)
let check_ocaml_version () =
  match get_ocaml_version () with
  | None -> Error (`Msg "Could not determine OCaml compiler version")
  | Some version_str -> (
      match parse_version version_str with
      | None ->
          Error
            (`Msg
               (Printf.sprintf "Could not parse OCaml version: %s" version_str))
      | Some (major, minor, _patch) ->
          if major > 5 || (major = 5 && minor >= 3) then Ok ()
          else
            Error
              (`Msg
                 (Printf.sprintf
                    "OCaml compiler version %s is below the minimum required \
                     version 5.3.0. Please upgrade your OCaml compiler to use \
                     prune."
                    version_str)))

(* {2 Merlin communication} *)

type merlin_mode = [ `Single | `Server ]
(* Merlin mode selection *)

let merlin_mode = ref `Single

let set_merlin_mode mode =
  merlin_mode := mode;
  (* Log merlin executable information on first use *)
  (match OS.Cmd.run_out Cmd.(v "which" % "ocamlmerlin") |> OS.Cmd.to_string with
  | Ok path -> Log.info (fun m -> m "Using ocamlmerlin: %s" (String.trim path))
  | Error _ -> Log.warn (fun m -> m "ocamlmerlin not found in PATH"));

  (* Log merlin version *)
  match
    OS.Cmd.run_out Cmd.(v "ocamlmerlin" % "-version") |> OS.Cmd.to_string
  with
  | Ok version ->
      Log.info (fun m -> m "Merlin version: %s" (String.trim version))
  | Error _ -> ()

(* Stop merlin server if running *)
let stop_merlin_server root_dir =
  if !merlin_mode = `Server then (
    Log.debug (fun m -> m "Stopping merlin server in %s" root_dir);
    (* Use shell command to ensure correct PATH/environment *)
    let shell_cmd =
      if root_dir = "." then "ocamlmerlin server stop-server"
      else
        Fmt.str "cd %s && ocamlmerlin server stop-server"
          (Filename.quote root_dir)
    in
    let cmd = Cmd.(v "sh" % "-c" % shell_cmd) in
    (* Run with stderr ignored *)
    match OS.Cmd.run ~err:OS.Cmd.err_null cmd with
    | Ok () -> Log.debug (fun m -> m "Merlin server stopped")
    | Error (`Msg err) ->
        Log.debug (fun m -> m "Failed to stop merlin server: %s" err))

(* Get relative path for a file from root directory *)

(* Run merlin with proper working directory context *)
let get_relative_path root_dir file_path =
  let fpath = Fpath.v file_path in
  (* If the path is already relative, just return it *)
  if Fpath.is_rel fpath then file_path
  else
    match Fpath.relativize ~root:(Fpath.v root_dir) fpath with
    | Some rel ->
        let rel_str = Fpath.to_string rel in
        Log.debug (fun m ->
            m "Relativized %s -> %s (root: %s)" file_path rel_str root_dir);
        rel_str
    | None ->
        Log.debug (fun m ->
            m "Could not relativize %s (root: %s)" file_path root_dir);
        file_path

(* Build merlin shell command *)
let build_merlin_command root_dir relative_path query =
  let merlin_cmd =
    match !merlin_mode with `Single -> "single" | `Server -> "server"
  in
  (* Build the full path for stdin redirection *)
  let full_path =
    if root_dir = "." then relative_path
    else Filename.concat root_dir relative_path
  in
  (* Use relative_path for -filename (merlin expects this) and full_path for
     stdin redirection *)
  Fmt.str "ocamlmerlin %s %s -filename %s < %s" merlin_cmd query
    (Filename.quote relative_path)
    (Filename.quote full_path)

(* Execute merlin command and parse output *)
let execute_merlin_command query_type shell_cmd =
  Log.debug (fun m -> m "Running merlin %s: %s" query_type shell_cmd);
  (* Run merlin directly without timeout wrapper *)
  let cmd = Cmd.(v "sh" % "-c" % shell_cmd) in
  match OS.Cmd.run_out ~err:OS.Cmd.err_null cmd |> OS.Cmd.out_string with
  | Ok (output_str, (_, status)) -> (
      match status with
      | `Exited 0 -> (
          try
            if output_str = "" then (
              Log.debug (fun m ->
                  m "Merlin %s returned empty output" query_type);
              `Null)
            else
              let json = Yojson.Safe.from_string output_str in
              Log.debug (fun m ->
                  m "Merlin %s completed successfully" query_type);
              json
          with exn ->
            Log.debug (fun m ->
                m "Failed to parse merlin %s output: %s (exception: %s)"
                  query_type output_str (Printexc.to_string exn));
            `Null)
      | `Exited n ->
          Log.debug (fun m -> m "Merlin %s exited with code %d" query_type n);
          `Null
      | `Signaled n ->
          Log.debug (fun m -> m "Merlin %s killed by signal %d" query_type n);
          `Null)
  | Error (`Msg err) ->
      Log.debug (fun m -> m "Merlin %s failed: %s" query_type err);
      `Null

let call_merlin root_dir file_path query =
  (* Check if file exists *)
  match OS.File.exists (Fpath.v file_path) with
  | Ok false | Error _ ->
      Log.debug (fun m -> m "File does not exist: %s" file_path);
      `Null
  | Ok true -> (
      let relative_path = get_relative_path root_dir file_path in
      (* Check if the relative path file exists from root_dir *)
      let full_path_from_root =
        if root_dir = "." then relative_path
        else Filename.concat root_dir relative_path
      in
      match OS.File.exists (Fpath.v full_path_from_root) with
      | Ok false | Error _ ->
          Log.debug (fun m ->
              m "Relative path does not exist from root: %s (root=%s, rel=%s)"
                full_path_from_root root_dir relative_path);
          `Null
      | Ok true ->
          let shell_cmd = build_merlin_command root_dir relative_path query in
          (* Extract query type from query string for better logging *)
          let query_type =
            if Re.execp (Re.compile (Re.str "outline")) query then "outline"
            else if Re.execp (Re.compile (Re.str "occurrences")) query then
              "occurrences"
            else "query"
          in
          execute_merlin_command query_type shell_cmd)

(* {2 Project validation} *)

(* Check if directory contains a dune project *)
let validate_dune_project root_dir =
  let root_path = Fpath.v root_dir in
  let dune_project = Fpath.(root_path / "dune-project") in
  match OS.File.exists dune_project with
  | Ok false | Error _ -> err_no_dune_project root_dir
  | Ok true -> Ok ()

(* {2 Dune build operations} *)

(* Run a build command and return structured result *)
let run_build_command _cmd_desc build_cmd =
  Log.debug (fun m -> m "Running: %s" (Cmd.to_string build_cmd));
  (* Use Bos to run command and capture both stdout and stderr together *)
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

(* Run single build that captures both index and warnings *)
let run_single_build root_dir ctx =
  Log.info (fun m -> m "Running build");
  (* Build all targets and ocaml-index for merlin to ensure proper indexing *)
  let build_cmd =
    Cmd.(v "dune" % "build" % "--root" % root_dir % "@all" % "@ocaml-index")
  in

  let result = run_build_command "build" build_cmd in
  let ctx = Types.update_build_result ctx result in

  (* Parse warnings from output *)
  let warnings = Warning.parse result.output in
  let ctx = Types.update_build_result ctx { result with warnings } in

  (ctx, warnings)

(* Build project and index for analysis *)
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
    match Types.get_last_build_result ctx with
    | Some result when result.success ->
        Log.debug (fun m -> m "Build completed successfully");
        Ok ()
    | _ ->
        (* Build failed - return error with context so caller can display the
           error *)
        Error (`Build_failed ctx)

(* Analyze the last build result and classify the error type *)
let classify_build_error ctx =
  match Types.get_last_build_result ctx with
  | None -> Types.Other_errors "No build result available"
  | Some result when result.success -> Types.No_error
  | Some result ->
      (* Check if we have errors that we can fix *)
      Log.debug (fun m -> m "Build failed with output:\n%s" result.output);
      (* Use already parsed warnings from build result *)
      let parsed_errors : Types.warning_info list = result.warnings in
      let fixable_errors =
        List.filter
          (fun w ->
            match w.Types.warning_type with
            | Types.Signature_mismatch | Types.Unbound_field -> true
            | Types.Unused_value -> true (* Warning 32 is fixable *)
            | Types.Unused_type -> true (* Warning 34 is fixable *)
            | Types.Unused_open -> true (* Warning 33 is fixable *)
            | Types.Unused_constructor -> true (* Warning 37 is fixable *)
            | Types.Unused_field -> true (* Warning 69 is fixable *)
            | Types.Unnecessary_mutable ->
                true
                (* Warning 69 mutable - fixable by removing mutable keyword *)
            | _ -> false)
          parsed_errors
      in
      Log.debug (fun m ->
          m "Found %d fixable errors" (List.length fixable_errors));
      if fixable_errors <> [] then Types.Fixable_errors fixable_errors
      else
        (* Include the actual build output to help users debug *)
        let output_excerpt =
          if String.length result.output > 1000 then
            String.sub result.output 0 1000 ^ "\n[... output truncated ...]"
          else result.output
        in
        Types.Other_errors output_excerpt

(* Helper to display build error and exit *)
let display_build_failure_and_exit ctx =
  let all_warnings =
    match Types.get_last_build_result ctx with
    | Some result -> result.warnings (* Use already parsed warnings *)
    | None -> []
  in
  let total_error_count = List.length all_warnings in

  (* Display build failure consistently *)
  Fmt.pr "%a with %d %s - full output:@."
    Fmt.(styled (`Fg `Red) string)
    "Build failed" total_error_count
    (if total_error_count = 1 then "error" else "errors");

  let pp_build_error ppf ctx =
    match Types.get_last_build_result ctx with
    | None -> Fmt.pf ppf "No build output available"
    | Some result -> Fmt.pf ppf "%s" result.output
  in
  Fmt.pr "%a@." pp_build_error ctx;

  (* Exit with build exit code *)
  let exit_code =
    match Types.get_last_build_result ctx with
    | Some result -> result.exit_code
    | None -> 1
  in
  exit exit_code
