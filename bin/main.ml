open Prune
open Bos
module Show = Prune.Show

(* Display analyzing message for mli files *)
let display_analyzing_message mli_files =
  let count = List.length mli_files in
  Prune.Output.header "Analyzing %d .mli file%s" count
    (if count = 1 then "" else "s")

(* Setup logging with colors *)
let setup_logs level =
  Logs.set_level level;
  Logs.set_reporter
    (Logs_fmt.reporter ~dst:Format.err_formatter ~app:Fmt.stdout ())

(* Check if a path should be excluded from analysis *)
let is_excluded path =
  let segments = Fpath.segs path in
  List.exists
    (fun seg -> seg = "_build" || seg = "_opam" || seg = ".git")
    segments

(* Recursively find all .mli files in a directory *)
let rec find_mli_files acc dir =
  match OS.Dir.contents dir with
  | Error _ -> acc
  | Ok paths ->
      List.fold_left
        (fun acc path ->
          if is_excluded path then acc
          else if Fpath.has_ext ".mli" path then path :: acc
          else
            match OS.Dir.exists path with
            | Ok true -> find_mli_files acc path
            | _ -> acc)
        acc paths

let get_mli_files root_dir files dirs =
  if files = [] && dirs = [] then
    (* No specific paths - find all .mli files in project *)
    let root_path = Fpath.v root_dir in
    let mli_files = find_mli_files [] root_path in
    List.map
      (fun p ->
        let s = Fpath.to_string p in
        (* Remove leading ./ if present *)
        if String.length s >= 2 && String.sub s 0 2 = "./" then
          String.sub s 2 (String.length s - 2)
        else s)
      mli_files
  else
    (* Specific files and directories *)
    let dir_mlis =
      List.concat_map
        (fun dir ->
          let mli_files = find_mli_files [] (Fpath.v dir) in
          List.map
            (fun p ->
              let s = Fpath.to_string p in
              (* Remove leading ./ if present *)
              if String.length s >= 2 && String.sub s 0 2 = "./" then
                String.sub s 2 (String.length s - 2)
              else s)
            mli_files)
        dirs
    in
    (* Only include .mli files from the files list *)
    let mli_files =
      List.filter (fun f -> Filename.check_suffix f ".mli") files
    in
    mli_files @ dir_mlis

let process_clean dry_run force step_wise use_merlin_server paths exclude_dirs
    log_level json =
  setup_logs log_level;

  (* Set output mode based on flags and log level *)
  (if json then Prune.Output.set_mode Prune.Output.Json
   else
     (* Default log level from Logs_cli is warning, so we need to handle this
        correctly *)
     match log_level with
     | Some Logs.Error -> Prune.Output.set_mode Prune.Output.Quiet
     | Some Logs.Debug | Some Logs.Info ->
         Prune.Output.set_mode Prune.Output.Verbose
     | Some Logs.Warning | Some Logs.App | None ->
         (* Default to Normal mode for warning level and above *)
         Prune.Output.set_mode Prune.Output.Normal);

  (* If no paths provided, use current directory *)
  let paths = if paths = [] then [ "." ] else paths in

  (* Check for non-existent paths and separate files from directories *)
  let check_path path =
    if not (Sys.file_exists path) then `Missing
    else if Sys.is_directory path then `Dir
    else `File
  in

  let results = List.map (fun p -> (p, check_path p)) paths in

  (* Report errors for non-existent paths *)
  let missing_paths =
    List.filter_map (function p, `Missing -> Some p | _ -> None) results
  in

  if missing_paths <> [] then (
    List.iter
      (fun p -> Prune.Output.error "%s: No such file or directory" p)
      missing_paths;
    exit 1);

  (* Extract existing files and directories *)
  let files =
    List.filter_map (function p, `File -> Some p | _ -> None) results
  in

  let dirs =
    List.filter_map (function p, `Dir -> Some p | _ -> None) results
  in

  (* Check for non-.mli files *)
  let non_mli_files =
    List.filter (fun f -> not (Filename.check_suffix f ".mli")) files
  in

  if non_mli_files <> [] then (
    List.iter
      (fun f ->
        Prune.Output.error "%s: prune only analyzes .mli files, not %s files" f
          (Filename.extension f))
      non_mli_files;
    exit 1);

  let root_dir = Sys.getcwd () in

  (* Set merlin mode *)
  set_merlin_mode (if use_merlin_server then `Server else `Single);

  (* Register cleanup function to stop merlin server if using server mode *)
  let cleanup () = stop_merlin_server root_dir in
  at_exit cleanup;

  (* Get all .mli files to analyze *)
  let mli_files = get_mli_files root_dir files dirs in

  (* Determine the mode based on flags *)
  let mode =
    if dry_run then `Dry_run else if step_wise then `Single_pass else `Iterative
  in

  display_analyzing_message mli_files;
  if mode = `Iterative && List.length mli_files > 0 then Fmt.pr "@.";

  match analyze ~yes:force ~exclude_dirs mode root_dir mli_files with
  | Ok _stats ->
      (* Summary is already printed by analyze *)
      ()
  | Error (`Msg "Cancelled by user") ->
      (* User cancelled - exit silently *)
      ()
  | Error (`Build_error ctx) ->
      (* Build failure - display output and exit with build's exit code *)
      Prune.System.display_failure_and_exit ctx
  | Error e ->
      (* Other errors - use generic error code *)
      Prune.Output.error "%a" pp_error e;
      exit 1

let process_doctor sample_mli log_level =
  setup_logs log_level;
  match Doctor.run_diagnostics "." sample_mli with
  | Ok () -> ()
  | Error _ -> exit 1

let process_show format output_dir paths log_level =
  setup_logs log_level;

  (* If no paths provided, use current directory *)
  let paths = if paths = [] then [ "." ] else paths in

  let root_dir = Sys.getcwd () in

  (* Get .mli files using the existing logic *)
  let files, dirs =
    List.partition
      (fun p -> Sys.file_exists p && not (Sys.is_directory p))
      paths
  in
  let mli_files = get_mli_files root_dir files dirs in

  display_analyzing_message mli_files;

  match Show.run ~format ~output_dir ~root_dir ~mli_files with
  | Ok () -> ()
  | Error (`Msg msg) ->
      Prune.Output.error "%s" msg;
      exit 1

open Cmdliner

(* Common arguments *)
let env = Cmd.Env.info "PRUNE_VERBOSE"

(* Clean subcommand arguments *)
let dry_run =
  let doc = "Only report what would be removed, don't actually remove" in
  Arg.(value & flag & info [ "dry-run" ] ~doc)

let force =
  let doc = "Force removal without prompting for confirmation" in
  Arg.(value & flag & info [ "f"; "force" ] ~doc)

let step_wise =
  let doc =
    "Use single-pass mode instead of iterative cleanup (only removes exports \
     once without cleaning implementations)"
  in
  Arg.(value & flag & info [ "s"; "step-wise" ] ~doc)

let merlin_server =
  let doc = "Use merlin server mode instead of single mode (experimental)" in
  Arg.(value & flag & info [ "server" ] ~doc)

let paths =
  let doc =
    "Specific .mli files or directories to analyze instead of entire project"
  in
  Arg.(value & pos_all string [] & info [] ~docv:"PATH" ~doc)

let exclude_dirs =
  let doc =
    "Directories to exclude from occurrence counting (e.g., test/, _build/). \
     Symbols used only in excluded directories will be reported separately."
  in
  Arg.(value & opt (list string) [] & info [ "exclude" ] ~docv:"DIR" ~doc)

let json =
  let doc = "Output in JSON format" in
  Arg.(value & flag & info [ "json" ] ~doc)

(* Doctor subcommand arguments *)
let sample_mli =
  let doc = "Sample .mli file to test merlin occurrences" in
  Arg.(value & pos 0 (some string) None & info [] ~docv:"MLI_FILE" ~doc)

(* Subcommands *)
let clean_cmd =
  let doc = "Find and remove unused exports in OCaml .mli files (default)" in
  let man =
    [
      `S Manpage.s_description;
      `P "$(tname) analyzes OCaml .mli interface files to find unused exports.";
      `P
        "It can analyze an entire dune project (default) or specific .mli \
         files.";
      `S Manpage.s_examples;
      `P "Analyze entire project:";
      `Pre "  $(mname) clean --dry-run";
      `P "Remove unused code iteratively (force mode):";
      `Pre "  $(mname) clean --force";
      `P "Analyze specific files:";
      `Pre "  $(mname) clean lib/foo.mli lib/bar.mli --dry-run";
      `P "Analyze specific directories:";
      `Pre "  $(mname) clean lib/ src/ --dry-run";
      `P "Use single-pass mode (no iterative cleanup):";
      `Pre "  $(mname) clean --step-wise --dry-run";
      `P "Remove unused exports from specific files without prompting:";
      `Pre "  $(mname) clean lib/foo.mli lib/bar.mli --force";
      `P "Exclude test directories from occurrence counting:";
      `Pre "  $(mname) clean --exclude test --exclude tests --dry-run";
    ]
  in
  let info = Cmd.info "clean" ~doc ~man in
  let term =
    Term.(
      const process_clean $ dry_run $ force $ step_wise $ merlin_server $ paths
      $ exclude_dirs $ Logs_cli.level ~env () $ json)
  in
  Cmd.v info term

let doctor_cmd =
  let doc = "Run diagnostics to check merlin and build setup" in
  let man =
    [
      `S Manpage.s_description;
      `P
        "$(tname) checks your environment and project setup to diagnose \
         potential issues with prune.";
      `P
        "It verifies that merlin is installed, properly configured, and can \
         find occurrences across your project.";
      `S Manpage.s_examples;
      `P "Run basic diagnostics:";
      `Pre "  $(mname) doctor";
      `P "Test merlin occurrences on a specific file:";
      `Pre "  $(mname) doctor lib/mymodule.mli";
    ]
  in
  let info = Cmd.info "doctor" ~doc ~man in
  let term =
    Term.(const process_doctor $ sample_mli $ Logs_cli.level ~env ())
  in
  Cmd.v info term

(* Show subcommand arguments *)
let format =
  let doc = "Output format (cli or html)" in
  let format_conv =
    let parse = function
      | "cli" -> Ok Show.Cli
      | "html" -> Ok Show.Html
      | s ->
          Error
            (`Msg (Fmt.str "unknown format '%s', expected 'cli' or 'html'" s))
    in
    let print fmt = function
      | Show.Cli -> Fmt.pf fmt "cli"
      | Show.Html -> Fmt.pf fmt "html"
    in
    Arg.conv (parse, print)
  in
  Arg.(value & opt format_conv Show.Cli & info [ "format" ] ~docv:"FORMAT" ~doc)

let output_dir =
  let doc = "Output directory for HTML format" in
  Arg.(value & opt (some string) None & info [ "o"; "output" ] ~docv:"DIR" ~doc)

let show_cmd =
  let doc = "Show symbol occurrence statistics" in
  let man =
    [
      `S Manpage.s_description;
      `P "$(tname) analyzes symbol occurrences and generates reports.";
      `P
        "It can output to the terminal (CLI format) or generate an HTML report.";
      `S Manpage.s_examples;
      `P "Show CLI report for entire project:";
      `Pre "  $(mname) show";
      `P "Generate HTML report:";
      `Pre "  $(mname) show --format html -o report";
      `P "Analyze specific directories:";
      `Pre "  $(mname) show lib/ src/";
    ]
  in
  let info = Cmd.info "show" ~doc ~man in
  let term =
    Term.(
      const process_show $ format $ output_dir $ paths $ Logs_cli.level ~env ())
  in
  Cmd.v info term

(* Main command group *)
let cmd =
  let doc = "Find and remove unused exports in OCaml projects" in
  let sdocs = Manpage.s_common_options in
  let man =
    [
      `S Manpage.s_description;
      `P
        "$(mname) is a tool that automatically removes unused exports from \
         OCaml .mli interface files.";
      `S Manpage.s_commands;
      `S Manpage.s_examples;
      `P "Remove unused exports:";
      `Pre "  $(mname) clean";
      `P "Run diagnostics:";
      `Pre "  $(mname) doctor";
      `S Manpage.s_see_also;
      `P "$(mname)-clean(1), $(mname)-doctor(1)";
    ]
  in
  let version =
    match Build_info.V1.version () with
    | None -> "dev"
    | Some v -> Build_info.V1.Version.to_string v
  in
  let info = Cmd.info "prune" ~version ~doc ~sdocs ~man in
  (* Set clean as the default command *)
  let default = Term.(ret (const (`Help (`Pager, None)))) in
  Cmd.group info ~default [ clean_cmd; doctor_cmd; show_cmd ]

let main () =
  (* Initialize logs with colors if terminal supports it *)
  Fmt_tty.setup_std_outputs ();

  (* Check OCaml version before proceeding *)
  (match Prune.System.check_ocaml_version () with
  | Ok () -> ()
  | Error (`Msg msg) ->
      Prune.Output.error "%s" msg;
      exit 1);

  Cmd.eval cmd |> exit

let () = main ()
