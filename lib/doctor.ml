(* Diagnostic tool for debugging merlin and build issues *)

open Bos
open Rresult
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

(* Parse merlin JSON response *)
let parse_merlin_response output =
  try
    let json = Yojson.Safe.from_string output in
    let open Yojson.Safe.Util in
    let class_field = json |> member "class" |> to_string_option in
    let cache = json |> member "cache" in
    (class_field, cache)
  with _ -> (None, `Null)

(* Run command with timeout *)
let run_with_timeout ?(timeout_secs = 5) cmd_str =
  let timeout_cmd =
    if Sys.os_type = "Unix" then Fmt.str "timeout %d %s" timeout_secs cmd_str
    else cmd_str (* Windows doesn't have timeout command *)
  in
  OS.Cmd.run_out ~err:OS.Cmd.err_null Cmd.(v "sh" % "-c" % timeout_cmd)
  |> OS.Cmd.to_string

(* Check if merlin is available *)
let check_merlin_available () =
  match run_with_timeout ~timeout_secs:2 "ocamlmerlin -version" with
  | Ok version ->
      let location =
        match run_with_timeout ~timeout_secs:2 "which ocamlmerlin" with
        | Ok path -> Fmt.str "Location: %s" (String.trim path)
        | Error _ -> "Location: Unable to determine"
      in
      {
        check_name = "Merlin availability";
        passed = true;
        message = "ocamlmerlin is installed";
        details = [ String.trim version; location ];
      }
  | Error _ ->
      {
        check_name = "Merlin availability";
        passed = false;
        message = "ocamlmerlin not found in PATH";
        details = [ "Install merlin with: opam install merlin" ];
      }

(* Check merlin cache statistics *)
let check_merlin_cache_stats root_dir sample_mli =
  let file =
    Option.value sample_mli
      ~default:(Fpath.(v root_dir / "test.ml") |> Fpath.to_string)
  in
  (* First, try a simple query to populate cache *)
  let cmd =
    Fmt.str
      "echo '' | ocamlmerlin single complete-prefix -position 1:0 -prefix '' \
       -filename '%s'"
      file
  in
  match run_with_timeout ~timeout_secs:3 cmd with
  | Error _ -> None
  | Ok output -> (
      (* Extract cache stats from JSON *)
      match parse_merlin_response output with
      | _, `Null -> None
      | _, cache -> (
          try
            let open Yojson.Safe.Util in
            let cmt = cache |> member "cmt" in
            match cmt with
            | `Null -> None
            | _ ->
                let miss = cmt |> member "miss" |> to_int_option in
                Some miss
          with _ -> None))

(* Check merlin project configuration using merlin itself *)
let check_merlin_config root_dir =
  (* Create a dummy file path to query merlin *)
  let test_file = Fpath.(v root_dir / "test.ml") |> Fpath.to_string in
  let cmd =
    Fmt.str "echo '' | ocamlmerlin single dump -what paths -filename '%s'"
      test_file
  in
  match run_with_timeout cmd with
  | Error _ ->
      {
        check_name = "Merlin configuration";
        passed = false;
        message = "Failed to query merlin configuration";
        details = [];
      }
  | Ok output -> (
      (* Check if merlin can load the project *)
      match parse_merlin_response output with
      | Some "return", _ ->
          let cache_warnings =
            match check_merlin_cache_stats root_dir None with
            | Some (Some misses) when misses > 5 ->
                [
                  Fmt.str "Warning: High merlin cache misses (%d) detected"
                    misses;
                  "This may indicate missing build artifacts or configuration \
                   issues";
                ]
            | _ -> []
          in
          {
            check_name = "Merlin configuration";
            passed = true;
            message = "Merlin can load project configuration";
            details = cache_warnings;
          }
      | Some "error", _ ->
          {
            check_name = "Merlin configuration";
            passed = false;
            message = "Merlin cannot load project configuration";
            details = [ "Ensure dune-project exists and project is built" ];
          }
      | _ ->
          {
            check_name = "Merlin configuration";
            passed = false;
            message = "Unexpected merlin output";
            details = [ String.sub output 0 (min 200 (String.length output)) ];
          })

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
      (* Check for .cmt files *)
      (* Use a more efficient check - just see if any .cmt files exist *)
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
      | Ok _ ->
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
(* Create test result for merlin occurrences *)
let make_merlin_test_result ?(details = []) passed message =
  { check_name = "Merlin occurrences test"; passed; message; details }

(* Get cache miss details for merlin test *)
let get_cache_miss_details root_dir sample_mli =
  match check_merlin_cache_stats root_dir (Some sample_mli) with
  | Some (Some misses) when misses > 2 ->
      [
        Fmt.str
          "High cache misses detected (%d) - merlin may not see all compiled \
           files"
          misses;
        "This can cause incorrect occurrence detection";
      ]
  | _ -> []

(* Process merlin occurrences response *)
let process_merlin_occurrences_response root_dir sample_mli output =
  match parse_merlin_response output with
  | Some "return", _ ->
      let details = get_cache_miss_details root_dir sample_mli in
      make_merlin_test_result true "Merlin occurrences command works" ~details
  | _ ->
      make_merlin_test_result false "Merlin returned unexpected output"
        ~details:
          [ "Output: " ^ String.sub output 0 (min 200 (String.length output)) ]

(* Test merlin occurrences command *)
let test_merlin_occurrences_command root_dir sample_mli =
  let cmd =
    Fmt.str
      "ocamlmerlin single occurrences -identifier-at 1:4 -scope project \
       -filename '%s' < '%s'"
      sample_mli sample_mli
  in
  match run_with_timeout cmd with
  | Error _ -> make_merlin_test_result false "Failed to run merlin occurrences"
  | Ok output -> process_merlin_occurrences_response root_dir sample_mli output

let test_merlin_occurrences root_dir sample_mli =
  (* Check if it's a directory *)
  match OS.Dir.exists (Fpath.v sample_mli) with
  | Ok true ->
      make_merlin_test_result false
        (Fmt.str "%s is a directory, not a file" sample_mli)
        ~details:[ "Provide a .mli file to test merlin occurrences" ]
  | _ -> (
      match OS.File.exists (Fpath.v sample_mli) with
      | Ok false | Error _ ->
          make_merlin_test_result false
            (Fmt.str "Sample file %s not found" sample_mli)
      | Ok true -> test_merlin_occurrences_command root_dir sample_mli)

(* Check if dune @ocaml-index target exists *)
let check_dune_available () =
  (* Just check if dune is available, don't actually run build *)
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
      match System.get_ocaml_version () with
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
  (* Define checks as functions to be called in order *)
  let check_fns =
    [
      ("OCaml version", fun () -> check_ocaml_version ());
      ("Merlin availability", fun () -> check_merlin_available ());
      ("Merlin configuration", fun () -> check_merlin_config root_dir);
      ("Build artifacts", fun () -> check_build_artifacts root_dir);
      ("Dune", fun () -> check_dune_available ());
    ]
  in

  (* Add merlin test if we have a sample file *)
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

  (* Run checks in order and collect results *)
  let checks = List.map (fun (_name, check_fn) -> check_fn ()) check_fns in

  (* Print results *)
  Fmt.pr "@[<v>Prune Doctor - Diagnostics Report@.@.";
  List.iter (fun result -> Fmt.pr "%a@." pp_diagnostic_result result) checks;

  (* Summary *)
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
