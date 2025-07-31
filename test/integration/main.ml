(* Integration tests that use real merlin functionality *)
open Alcotest
open Prune
open Prune.Removal
module Cache = Prune.Cache

(* Helper to check if content contains a line starting with substring *)
let contains content sub =
  match
    String.split_on_char '\n' content
    |> List.find_opt (fun line ->
           String.length line >= String.length sub
           && String.sub line 0 (String.length sub) = sub)
  with
  | Some _ -> true
  | None -> false

(* Helper to check removal results *)
let check_removal_results content =
  check bool "unused value removed" false (contains content "val unused");
  check bool "unused type removed" false (contains content "type unused_t");
  check bool "used value remains" true (contains content "val used");
  check bool "used type remains" true (contains content "type used_t")

(* Helper to create a temporary OCaml project *)
let with_temp_project test_name content_mli content_ml f =
  let temp_dir = Filename.temp_file test_name "" in
  Sys.remove temp_dir;
  Unix.mkdir temp_dir 0o755;

  let mli_file = Filename.concat temp_dir "test.mli" in
  let ml_file = Filename.concat temp_dir "test.ml" in

  let oc = open_out mli_file in
  output_string oc content_mli;
  close_out oc;

  let oc = open_out ml_file in
  output_string oc content_ml;
  close_out oc;

  (* Create a simple dune file *)
  let dune_file = Filename.concat temp_dir "dune" in
  let oc = open_out dune_file in
  output_string oc "(library (name test))";
  close_out oc;

  try
    let result = f temp_dir mli_file ml_file in
    (* Clean up *)
    Sys.remove mli_file;
    Sys.remove ml_file;
    Sys.remove dune_file;
    Unix.rmdir temp_dir;
    result
  with e ->
    (* Clean up on error *)
    (try Sys.remove mli_file with Sys_error _ -> ());
    (try Sys.remove ml_file with Sys_error _ -> ());
    (try Sys.remove dune_file with Sys_error _ -> ());
    (try Unix.rmdir temp_dir with Unix.Unix_error _ -> ());
    raise e

(* Test the full removal flow with real files *)
(* Helper to create unused symbols for test *)
let unused_symbols mli_file =
  [
    {
      name = "unused";
      kind = Value;
      location =
        location mli_file ~line:5 ~start_col:0 (* Start of line *)
          ~end_line:5 ~end_col:29
        (* End of "val unused : string -> string" *);
    };
    {
      name = "unused_t";
      kind = Type;
      location =
        location mli_file ~line:11 ~start_col:0 (* Start of line *)
          ~end_line:11 ~end_col:21
        (* End of "type unused_t = float" *);
    };
  ]

let test_remove_unused_exports_real () =
  let mli_content =
    {|(** Used value *)
val used : int -> int

(** Unused value *)
val unused : string -> string

(** Used type *)
type used_t = int

(** Unused type *)
type unused_t = float|}
  in

  let ml_content =
    {|let used x = x * 2
let unused s = s ^ "_test"
type used_t = int
type unused_t = float|}
  in

  with_temp_project "test_removal" mli_content ml_content
    (fun root_dir mli_file _ml_file ->
      let symbols = unused_symbols mli_file in
      let cache = Cache.v () in
      match remove_unused_exports ~cache root_dir mli_file symbols with
      | Error e -> failf "Unexpected error: %a" pp_error e
      | Ok () ->
          (* Read the modified file *)
          let ic = open_in mli_file in
          let content = really_input_string ic (in_channel_length ic) in
          close_in ic;

          (* Check results *)
          check_removal_results content)

(* Helper to create test module data *)
let module_test_data () =
  let symbols =
    [
      {
        name = "M";
        kind = Module;
        location =
          location "test.mli" ~line:1 ~start_col:0 ~end_line:10 ~end_col:3;
      };
      {
        name = "foo";
        kind = Value;
        location =
          location "test.mli" ~line:3 ~start_col:2 ~end_line:3 ~end_col:20;
      };
      {
        name = "bar";
        kind = Value;
        location =
          location "test.mli" ~line:5 ~start_col:2 ~end_line:5 ~end_col:20;
      };
    ]
  in
  let occurrence_data =
    [
      {
        symbol = List.nth symbols 0;
        occurrences = 0;
        locations = [];
        usage_class = Unused;
      };
      {
        symbol = List.nth symbols 1;
        occurrences = 2;
        locations = [];
        usage_class = Used;
      };
      {
        symbol = List.nth symbols 2;
        occurrences = 0;
        locations = [];
        usage_class = Unused;
      };
    ]
  in
  (symbols, occurrence_data)

(* Test module filtering logic *)
let test_module_filtering () =
  let _symbols, occurrence_data = module_test_data () in

  let unused = List.filter (fun occ -> occ.occurrences = 0) occurrence_data in

  (* Apply module filtering *)
  let filtered = Analysis.filter_modules_with_used unused occurrence_data in

  (* Module M should be filtered out because it contains used symbol foo *)
  check int "only bar should remain" 1 (List.length filtered);
  check string "bar is the remaining symbol" "bar"
    (List.hd filtered).symbol.name

let suite =
  let open Alcotest in
  ( "Integration tests",
    [
      (* Tests removed - mark_lines_for_removal is no longer public API *)
      test_case "remove_unused_exports with real files" `Quick
        test_remove_unused_exports_real;
      test_case "module filtering preserves modules with used contents" `Quick
        test_module_filtering;
    ] )

let () = Alcotest.run "Prune integration tests" [ suite ]
