(* Unit tests for the Types module - jsont schemas and JSON parsing *)
open Alcotest

(* Testables for types *)
let symbol_kind : Prune.symbol_kind Alcotest.testable =
  Alcotest.testable
    (fun fmt k -> Fmt.string fmt (Prune.string_of_symbol_kind k))
    ( = )

let location_precision_testable : Prune.location_precision Alcotest.testable =
  let pp fmt = function
    | Prune.Exact_definition -> Fmt.string fmt "Exact_definition"
    | Prune.Exact_statement -> Fmt.string fmt "Exact_statement"
    | Prune.Needs_enclosing_definition ->
        Fmt.string fmt "Needs_enclosing_definition"
    | Prune.Needs_field_usage_parsing ->
        Fmt.string fmt "Needs_field_usage_parsing"
  in
  Alcotest.testable pp ( = )

(* Helper to handle all error cases *)
let fail_on_error msg = function
  | Ok v -> v
  | Error e -> failf "%s: %a" msg Prune.pp_error e

(* Test that the module loads correctly *)
let test_module_loads () = check bool "module loads" true true

(* Test location construction *)
let test_location_construction () =
  let loc = Prune.location "test.ml" ~line:10 ~start_col:5 ~end_col:15 in
  check string "file" "test.ml" loc.file;
  check int "start_line" 10 loc.start_line;
  check int "start_col" 5 loc.start_col;
  check int "end_line" 10 loc.end_line;
  check int "end_col" 15 loc.end_col

let test_location_with_end_line () =
  let loc =
    Prune.location "test.ml" ~line:10 ~end_line:15 ~start_col:5 ~end_col:20
  in
  check int "start_line" 10 loc.start_line;
  check int "end_line" 15 loc.end_line

let test_location_normalizes_path () =
  (* Location should strip ./ prefix *)
  let loc = Prune.location "./lib/test.ml" ~line:1 ~start_col:0 ~end_col:10 in
  check string "file normalized" "lib/test.ml" loc.file

(* Test location merge *)
let test_location_merge () =
  let loc1 = Prune.location "test.ml" ~line:5 ~start_col:0 ~end_col:10 in
  let loc2 = Prune.location "test.ml" ~line:10 ~start_col:5 ~end_col:20 in
  let merged = Prune.merge loc1 loc2 in
  check string "merged file" "test.ml" merged.file;
  check int "merged start_line" 5 merged.start_line;
  check int "merged end_line" 10 merged.end_line;
  check int "merged start_col" 0 merged.start_col;
  check int "merged end_col" 20 merged.end_col

let test_location_merge_same_line () =
  let loc1 = Prune.location "test.ml" ~line:5 ~start_col:0 ~end_col:10 in
  let loc2 = Prune.location "test.ml" ~line:5 ~start_col:15 ~end_col:25 in
  let merged = Prune.merge loc1 loc2 in
  check int "merged start_col" 0 merged.start_col;
  check int "merged end_col" 25 merged.end_col

(* Test location extension *)
let test_location_extend () =
  let loc = Prune.location "test.ml" ~line:5 ~start_col:0 ~end_col:10 in
  let extended = Prune.extend ~end_line:10 loc in
  check int "extended end_line" 10 extended.end_line;
  check int "original start_line preserved" 5 extended.start_line

let test_location_extend_with_start () =
  let loc = Prune.location "test.ml" ~line:5 ~start_col:0 ~end_col:10 in
  let extended = Prune.extend ~start_line:3 ~end_line:10 loc in
  check int "new start_line" 3 extended.start_line;
  check int "new end_line" 10 extended.end_line

(* Test string_of_symbol_kind *)
let test_string_of_symbol_kind () =
  check string "Value" "value" (Prune.string_of_symbol_kind Prune.Value);
  check string "Type" "type" (Prune.string_of_symbol_kind Prune.Type);
  check string "Module" "module" (Prune.string_of_symbol_kind Prune.Module);
  check string "Constructor" "constructor"
    (Prune.string_of_symbol_kind Prune.Constructor);
  check string "Field" "field" (Prune.string_of_symbol_kind Prune.Field)

(* Test jsont parsing - outline_response_of_json *)
let test_outline_response_null_json () =
  (* Null JSON should return empty list *)
  let json_null = Jsont.Null ((), Jsont.Meta.none) in
  let items =
    fail_on_error "null json"
      (Prune.outline_response_of_json ~file:"test.ml" json_null)
  in
  check int "null returns empty list" 0 (List.length items)

let test_outline_response_empty () =
  (* Empty outline response *)
  let json_str = {|{"class": "return", "value": []}|} in
  match Jsont_bytesrw.decode_string Jsont.json json_str with
  | Error e -> failf "Failed to parse JSON: %s" e
  | Ok json ->
      let items =
        fail_on_error "outline parsing"
          (Prune.outline_response_of_json ~file:"test.ml" json)
      in
      check int "empty value returns empty list" 0 (List.length items)

let test_outline_response_single_value () =
  (* Single value in outline *)
  let json_str =
    {|{
      "class": "return",
      "value": [{
        "kind": "Value",
        "name": "foo",
        "start": {"line": 1, "col": 0},
        "end": {"line": 1, "col": 10},
        "children": []
      }]
    }|}
  in
  match Jsont_bytesrw.decode_string Jsont.json json_str with
  | Error e -> failf "Failed to parse JSON: %s" e
  | Ok json ->
      let items =
        fail_on_error "outline parsing"
          (Prune.outline_response_of_json ~file:"test.ml" json)
      in
      check int "one item" 1 (List.length items);
      let item = List.hd items in
      check string "name" "foo" item.name;
      check symbol_kind "kind" Prune.Value item.kind;
      check int "start_line" 1 item.location.start_line;
      check int "start_col" 0 item.location.start_col

let test_outline_response_multiple_items () =
  (* Multiple items in outline *)
  let json_str =
    {|{
      "class": "return",
      "value": [
        {"kind": "Value", "name": "foo", "start": {"line": 1, "col": 0}, "children": []},
        {"kind": "Type", "name": "bar", "start": {"line": 5, "col": 0}, "children": []},
        {"kind": "Module", "name": "Baz", "start": {"line": 10, "col": 0}, "children": []}
      ]
    }|}
  in
  match Jsont_bytesrw.decode_string Jsont.json json_str with
  | Error e -> failf "Failed to parse JSON: %s" e
  | Ok json ->
      let items =
        fail_on_error "outline parsing"
          (Prune.outline_response_of_json ~file:"test.ml" json)
      in
      check int "three items" 3 (List.length items);
      let kinds = List.map (fun (i : Prune.outline_item) -> i.kind) items in
      check (list symbol_kind) "kinds"
        [ Prune.Value; Prune.Type; Prune.Module ]
        kinds

let test_outline_response_with_children () =
  (* Nested outline with children *)
  let json_str =
    {|{
      "class": "return",
      "value": [{
        "kind": "Module",
        "name": "MyModule",
        "start": {"line": 1, "col": 0},
        "end": {"line": 20, "col": 3},
        "children": [
          {"kind": "Value", "name": "inner_val", "start": {"line": 5, "col": 2}, "children": []},
          {"kind": "Type", "name": "inner_type", "start": {"line": 10, "col": 2}, "children": []}
        ]
      }]
    }|}
  in
  match Jsont_bytesrw.decode_string Jsont.json json_str with
  | Error e -> failf "Failed to parse JSON: %s" e
  | Ok json -> (
      let items =
        fail_on_error "outline parsing"
          (Prune.outline_response_of_json ~file:"test.ml" json)
      in
      check int "one top-level item" 1 (List.length items);
      let module_item = List.hd items in
      check string "module name" "MyModule" module_item.name;
      match module_item.children with
      | None -> fail "Should have children"
      | Some children ->
          check int "two children" 2 (List.length children);
          let names =
            List.map (fun (i : Prune.outline_item) -> i.name) children
          in
          check (list string) "child names" [ "inner_val"; "inner_type" ] names)

let test_outline_skips_unknown_kinds () =
  (* Unknown kinds should be skipped *)
  let json_str =
    {|{
      "class": "return",
      "value": [
        {"kind": "Value", "name": "known", "start": {"line": 1, "col": 0}, "children": []},
        {"kind": "UnknownKind", "name": "unknown", "start": {"line": 5, "col": 0}, "children": []},
        {"kind": "Type", "name": "also_known", "start": {"line": 10, "col": 0}, "children": []}
      ]
    }|}
  in
  match Jsont_bytesrw.decode_string Jsont.json json_str with
  | Error e -> failf "Failed to parse JSON: %s" e
  | Ok json ->
      let items =
        fail_on_error "outline parsing"
          (Prune.outline_response_of_json ~file:"test.ml" json)
      in
      check int "two items (unknown skipped)" 2 (List.length items);
      let names = List.map (fun (i : Prune.outline_item) -> i.name) items in
      check (list string) "only known items" [ "known"; "also_known" ] names

(* Test jsont parsing - occurrences_response_of_json *)
let test_occurrences_response_null_json () =
  (* Null JSON should return empty list *)
  let json_null = Jsont.Null ((), Jsont.Meta.none) in
  let items =
    fail_on_error "null json"
      (Prune.occurrences_response_of_json ~root_dir:"." json_null)
  in
  check int "null returns empty list" 0 (List.length items)

let test_occurrences_response_empty () =
  (* Empty occurrences response *)
  let json_str = {|{"class": "return", "value": []}|} in
  match Jsont_bytesrw.decode_string Jsont.json json_str with
  | Error e -> failf "Failed to parse JSON: %s" e
  | Ok json ->
      let items =
        fail_on_error "occurrences parsing"
          (Prune.occurrences_response_of_json ~root_dir:"." json)
      in
      check int "empty value returns empty list" 0 (List.length items)

let test_occurrences_response_single () =
  (* Single occurrence *)
  let json_str =
    {|{
      "class": "return",
      "value": [{
        "start": {"line": 10, "col": 5},
        "end": {"line": 10, "col": 15},
        "file": "lib/test.ml"
      }]
    }|}
  in
  match Jsont_bytesrw.decode_string Jsont.json json_str with
  | Error e -> failf "Failed to parse JSON: %s" e
  | Ok json ->
      let items =
        fail_on_error "occurrences parsing"
          (Prune.occurrences_response_of_json ~root_dir:"." json)
      in
      check int "one occurrence" 1 (List.length items);
      let loc = List.hd items in
      check string "file" "lib/test.ml" loc.file;
      check int "start_line" 10 loc.start_line;
      check int "start_col" 5 loc.start_col;
      check int "end_col" 15 loc.end_col

let test_occurrences_response_multiple () =
  (* Multiple occurrences *)
  let json_str =
    {|{
      "class": "return",
      "value": [
        {"start": {"line": 5, "col": 0}, "file": "a.ml"},
        {"start": {"line": 10, "col": 5}, "file": "b.ml"},
        {"start": {"line": 15, "col": 10}, "file": "c.ml"}
      ]
    }|}
  in
  match Jsont_bytesrw.decode_string Jsont.json json_str with
  | Error e -> failf "Failed to parse JSON: %s" e
  | Ok json ->
      let items =
        fail_on_error "occurrences parsing"
          (Prune.occurrences_response_of_json ~root_dir:"." json)
      in
      check int "three occurrences" 3 (List.length items);
      let files = List.map (fun (l : Prune.location) -> l.file) items in
      check (list string) "files" [ "a.ml"; "b.ml"; "c.ml" ] files

let test_occurrences_relativizes_paths () =
  (* Test that file paths are relativized *)
  let json_str =
    {|{
      "class": "return",
      "value": [{
        "start": {"line": 1, "col": 0},
        "file": "/home/user/project/lib/test.ml"
      }]
    }|}
  in
  match Jsont_bytesrw.decode_string Jsont.json json_str with
  | Error e -> failf "Failed to parse JSON: %s" e
  | Ok json ->
      let items =
        fail_on_error "occurrences parsing"
          (Prune.occurrences_response_of_json ~root_dir:"/home/user/project"
             json)
      in
      check int "one occurrence" 1 (List.length items);
      let loc = List.hd items in
      check string "file relativized" "lib/test.ml" loc.file

let test_occurrences_handles_missing_file () =
  (* Test handling when file field is missing *)
  let json_str =
    {|{
      "class": "return",
      "value": [{
        "start": {"line": 1, "col": 0}
      }]
    }|}
  in
  match Jsont_bytesrw.decode_string Jsont.json json_str with
  | Error e -> failf "Failed to parse JSON: %s" e
  | Ok json ->
      let items =
        fail_on_error "occurrences parsing"
          (Prune.occurrences_response_of_json ~root_dir:"." json)
      in
      check int "one occurrence" 1 (List.length items);
      let loc = List.hd items in
      check string "empty file when missing" "" loc.file

(* Test warning_type precision *)
let test_warning_precision () =
  let open Prune in
  check location_precision_testable "Unused_value" Needs_enclosing_definition
    (precision_of_warning_type Unused_value);
  check location_precision_testable "Unused_type" Exact_definition
    (precision_of_warning_type Unused_type);
  check location_precision_testable "Unused_open" Exact_statement
    (precision_of_warning_type Unused_open);
  check location_precision_testable "Unused_field" Exact_statement
    (precision_of_warning_type Unused_field);
  check location_precision_testable "Unbound_field" Needs_field_usage_parsing
    (precision_of_warning_type Unbound_field)

(* Test stats *)
let test_empty_stats () =
  let stats = Prune.empty_stats in
  check int "mli_exports_removed" 0 stats.mli_exports_removed;
  check int "ml_implementations_removed" 0 stats.ml_implementations_removed;
  check int "iterations" 0 stats.iterations;
  check int "lines_removed" 0 stats.lines_removed

let test_stats_formatting () =
  let stats =
    {
      Prune.mli_exports_removed = 5;
      ml_implementations_removed = 3;
      iterations = 2;
      lines_removed = 50;
    }
  in
  let output = Fmt.str "%a" Prune.pp_stats stats in
  check bool "contains exports" true (String.length output > 0);
  check bool "not empty for non-zero" true (not (String.equal output ""))

let test_stats_zero_iterations_silent () =
  let stats = { Prune.empty_stats with iterations = 0 } in
  let output = Fmt.str "%a" Prune.pp_stats stats in
  check string "zero iterations produces no output" "" output

(* Test symbol_kind_of_warning *)
let test_symbol_kind_of_warning () =
  check symbol_kind "Unused_value" Prune.Value
    (Prune.symbol_kind_of_warning Prune.Unused_value);
  check symbol_kind "Unused_type" Prune.Type
    (Prune.symbol_kind_of_warning Prune.Unused_type);
  check symbol_kind "Unused_open" Prune.Module
    (Prune.symbol_kind_of_warning Prune.Unused_open);
  check symbol_kind "Unused_constructor" Prune.Constructor
    (Prune.symbol_kind_of_warning Prune.Unused_constructor);
  check symbol_kind "Unused_field" Prune.Field
    (Prune.symbol_kind_of_warning Prune.Unused_field)

let suite =
  ( "types",
    [
      test_case "module loads" `Quick test_module_loads;
      (* Location tests *)
      test_case "location construction" `Quick test_location_construction;
      test_case "location with end_line" `Quick test_location_with_end_line;
      test_case "location normalizes path" `Quick test_location_normalizes_path;
      test_case "location merge" `Quick test_location_merge;
      test_case "location merge same line" `Quick test_location_merge_same_line;
      test_case "location extend" `Quick test_location_extend;
      test_case "location extend with start" `Quick
        test_location_extend_with_start;
      (* Symbol kind tests *)
      test_case "string_of_symbol_kind" `Quick test_string_of_symbol_kind;
      test_case "symbol_kind_of_warning" `Quick test_symbol_kind_of_warning;
      (* Outline JSON parsing tests *)
      test_case "outline null json" `Quick test_outline_response_null_json;
      test_case "outline empty response" `Quick test_outline_response_empty;
      test_case "outline single value" `Quick test_outline_response_single_value;
      test_case "outline multiple items" `Quick
        test_outline_response_multiple_items;
      test_case "outline with children" `Quick
        test_outline_response_with_children;
      test_case "outline skips unknown kinds" `Quick
        test_outline_skips_unknown_kinds;
      (* Occurrences JSON parsing tests *)
      test_case "occurrences null json" `Quick
        test_occurrences_response_null_json;
      test_case "occurrences empty response" `Quick
        test_occurrences_response_empty;
      test_case "occurrences single" `Quick test_occurrences_response_single;
      test_case "occurrences multiple" `Quick test_occurrences_response_multiple;
      test_case "occurrences relativizes paths" `Quick
        test_occurrences_relativizes_paths;
      test_case "occurrences handles missing file" `Quick
        test_occurrences_handles_missing_file;
      (* Warning precision tests *)
      test_case "warning precision" `Quick test_warning_precision;
      (* Stats tests *)
      test_case "empty stats" `Quick test_empty_stats;
      test_case "stats formatting" `Quick test_stats_formatting;
      test_case "stats zero iterations silent" `Quick
        test_stats_zero_iterations_silent;
    ] )
