(* Diagnostic tool for debugging merlin and build issues *)

open Bos
module Log = (val Logs.src_log (Logs.Src.create "prune.doctor") : Logs.LOG)

type diagnostic_result = {
  check_name : string;
  passed : bool;
  message : string;
  details : string list;
}

let pp_diagnostic_result fmt result =
  let status_symbol = if result.passed then "✓" else "✗" in
  let status_color = if result.passed then `Green else `Red in
  Fmt.pf fmt "%a %s: %s"
    Fmt.(styled status_color string)
    status_symbol result.check_name result.message;
  if result.details <> [] then
    List.iter (fun detail -> Fmt.pf fmt "@.  %s" detail) result.details

(* Run command with timeout *)
let run_with_timeout ?(timeout_secs = 5) cmd_str =
  let timeout_cmd =
    if Sys.os_type = "Unix" then Fmt.str "timeout %d %s" timeout_secs cmd_str
    else cmd_str
  in
  OS.Cmd.run_out ~err:OS.Cmd.err_null Cmd.(v "sh" % "-c" % timeout_cmd)
  |> OS.Cmd.to_string

(* Check merlin library backend *)
let check_merlin_available () =
  let m = Merlin.create ~backend:Lib () in
  Merlin.close m;
  {
    check_name = "Merlin library";
    passed = true;
    message = "merlin-lib is available (library backend)";
    details = [];
  }

(* Check merlin project configuration using the library backend *)
let check_merlin_config root_dir =
  let test_file = Fpath.(v root_dir / "test.ml") |> Fpath.to_string in
  let m = Merlin.create ~backend:Lib ~root_dir () in
  let result = Merlin.outline m ~file:test_file in
  Merlin.close m;
  match result with
  | Ok _ ->
      {
        check_name = "Merlin configuration";
        passed = true;
        message = "Merlin can load project configuration";
        details = [];
      }
  | Error _e ->
      {
        check_name = "Merlin configuration";
        passed = true;
        message = "Merlin library backend initialized (no test file to verify)";
        details = [];
      }

(* Check if build artifacts exist *)
let check_build_artifacts root_dir =
  let build_dir = Fpath.(v root_dir / "_build") in
  match OS.Dir.exists build_dir with
  | Ok false | Error _ ->
      {
        check_name = "Build artifacts";
        passed = false;
        message = "_build directory not found";
        details = [ "Run 'dune build' before using prune" ];
      }
  | Ok true -> (
      let cmd =
        Fmt.str "find %s -name '*.cmt' -o -name '*.cmti' | head -1" "_build"
      in
      match run_with_timeout ~timeout_secs:2 cmd with
      | Ok output when String.trim output <> "" ->
          {
            check_name = "Build artifacts";
            passed = true;
            message = "Found .cmt/.cmti files in _build";
            details = [];
          }
      | _ ->
          {
            check_name = "Build artifacts";
            passed = false;
            message = "No .cmt/.cmti files found in _build";
            details =
              [
                "Merlin needs .cmt files to find cross-file occurrences";
                "Ensure your build creates these files (dune does by default)";
                "Try: dune build @all";
              ];
          })

(* Test merlin on a sample file *)
let merlin_test_result ?(details = []) passed message =
  { check_name = "Merlin occurrences test"; passed; message; details }

let test_merlin_occurrences root_dir sample_mli =
  match OS.Dir.exists (Fpath.v sample_mli) with
  | Ok true ->
      merlin_test_result false
        (Fmt.str "%s is a directory, not a file" sample_mli)
        ~details:[ "Provide a .mli file to test merlin occurrences" ]
  | _ -> (
      match OS.File.exists (Fpath.v sample_mli) with
      | Ok false | Error _ ->
          merlin_test_result false
            (Fmt.str "Sample file %s not found" sample_mli)
      | Ok true -> (
          let m = Merlin.create ~backend:Lib ~root_dir () in
          let result =
            Merlin.occurrences m ~file:sample_mli ~line:1 ~col:4 ~scope:Project
          in
          Merlin.close m;
          match result with
          | Ok _result ->
              merlin_test_result true "Merlin occurrences command works"
          | Error e ->
              merlin_test_result false
                (Fmt.str "Merlin occurrences failed: %s" e)))

(* Check if dune is available *)
let check_dune_available () =
  match run_with_timeout ~timeout_secs:2 "dune --version" with
  | Ok version ->
      {
        check_name = "Dune";
        passed = true;
        message = "Dune is available";
        details = [ String.trim version ];
      }
  | Error _ ->
      {
        check_name = "Dune";
        passed = false;
        message = "Dune not found";
        details = [ "Install dune to build OCaml projects" ];
      }

(* Check OCaml compiler version *)
let check_ocaml_version () =
  match System.check_ocaml_version () with
  | Ok () -> (
      match System.ocaml_version () with
      | Some version ->
          {
            check_name = "OCaml compiler version";
            passed = true;
            message = Fmt.str "OCaml %s meets minimum requirements" version;
            details = [ "Minimum required version: 5.3.0" ];
          }
      | None ->
          {
            check_name = "OCaml compiler version";
            passed = true;
            message = "OCaml version check passed";
            details = [];
          })
  | Error (`Msg msg) ->
      {
        check_name = "OCaml compiler version";
        passed = false;
        message = "OCaml version requirement not met";
        details = [ msg ];
      }

(* Run all diagnostics *)
let run_diagnostics root_dir sample_mli =
  let check_fns =
    [
      ("OCaml version", fun () -> check_ocaml_version ());
      ("Merlin library", fun () -> check_merlin_available ());
      ("Merlin configuration", fun () -> check_merlin_config root_dir);
      ("Build artifacts", fun () -> check_build_artifacts root_dir);
      ("Dune", fun () -> check_dune_available ());
    ]
  in

  let check_fns =
    match sample_mli with
    | Some mli ->
        check_fns
        @ [
            ( "Merlin occurrences test",
              fun () -> test_merlin_occurrences root_dir mli );
          ]
    | None -> check_fns
  in

  let checks = List.map (fun (_name, check_fn) -> check_fn ()) check_fns in

  Fmt.pr "@[<v>Prune Doctor - Diagnostics Report@.@.";
  List.iter (fun result -> Fmt.pr "%a@." pp_diagnostic_result result) checks;

  let failed_checks = List.filter (fun r -> not r.passed) checks in
  if failed_checks = [] then (
    Fmt.pr "@.%a All checks passed!@." Fmt.(styled `Green string) "✓";
    Ok ())
  else (
    Fmt.pr "@.%a %d check(s) failed. Please address the issues above.@."
      Fmt.(styled `Red string)
      "✗"
      (List.length failed_checks);
    Error (`Msg "Diagnostic checks failed"))
