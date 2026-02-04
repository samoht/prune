(* Tests for the Warning module *)
open Alcotest
open Prune

(* Testables for warning types *)
let warning_type : Prune.warning_type Alcotest.testable =
  Alcotest.testable Prune.pp_warning_type ( = )

let warning_info : Prune.warning_info Alcotest.testable =
  Alcotest.testable Prune.pp_warning_info ( = )

let test_simple_parsing () =
  let input =
    {|File "lib/prune.ml", line 15, characters 4-17:
15 |     let unused_helper x = x + 1
         ^^^^^^^^^^^^^
Warning 32 [unused-value-declaration]: unused value unused_helper.|}
  in
  let result = Prune.Warning.parse input in
  check int "should parse 1 warning" 1 (List.length result);
  match result with
  | [ w ] ->
      check string "warning name" "unused_helper" w.name;
      check string "file" "lib/prune.ml" w.location.file;
      check int "line" 15 w.location.start_line
  | _ -> fail "Expected exactly one warning"

(* Helper to create single warning test case *)
let single_warning_case =
  ( {|File "lib/prune.ml", line 15, characters 4-17:
15 |     let unused_helper x = x + 1
         ^^^^^^^^^^^^^
Warning 32 [unused-value-declaration]: unused value unused_helper.|},
    [
      {
        location =
          Prune.location "lib/prune.ml" ~line:15 ~start_col:4 ~end_col:17;
        name = "unused_helper";
        warning_type = Unused_value;
        location_precision = Prune.Needs_enclosing_definition;
      };
    ] )

(* Helper to create multiple warnings test case *)
let multiple_warnings_case =
  ( {|File "lib/test.ml", line 10, characters 2-15:
10 |   let unused_val = 42
       ^^^^^^^^^^^^^
Warning 32 [unused-value-declaration]: unused value unused_val.
File "lib/test.ml", line 20, characters 4-20:
20 | type unused_type = int
         ^^^^^^^^^^^^
Warning 34 [unused-type-declaration]: unused type unused_type.|},
    [
      {
        location =
          Prune.location "lib/test.ml" ~line:10 ~start_col:2 ~end_col:15;
        name = "unused_val";
        warning_type = Unused_value;
        location_precision = Prune.Needs_enclosing_definition;
      };
      {
        location =
          Prune.location "lib/test.ml" ~line:20 ~start_col:4 ~end_col:20;
        name = "unused_type";
        warning_type = Unused_type;
        location_precision = Prune.Exact_definition;
      };
    ] )

let test_parse_warnings () =
  let test_cases =
    [
      single_warning_case;
      multiple_warnings_case;
      (* Test with no warnings *)
      ({|Build successful with no warnings|}, []);
    ]
  in
  List.iter
    (fun (input, expected) ->
      let result = Prune.Warning.parse input in
      check (list warning_info) "Warning.parse" expected result)
    test_cases

let warning_32_edge_cases () =
  (* Test various edge cases for warning 32 *)
  let test_cases =
    [
      (* Warning promoted to error *)
      ( {|File "lib/test.ml", line 5, characters 4-10:
5 | let foo = 1
        ^^^
Error (warning 32 [unused-value-declaration]): unused value foo.|},
        [
          {
            location =
              Prune.location "lib/test.ml" ~line:5 ~start_col:4 ~end_col:10;
            name = "foo";
            warning_type = Unused_value;
            location_precision = Prune.Needs_enclosing_definition;
          };
        ] );
      (* Complex function name *)
      ( {|File "src/parser.ml", line 100, characters 8-25:
100 |     let parse_expression = fun x -> x
             ^^^^^^^^^^^^^^^^^
Warning 32 [unused-value-declaration]: unused value parse_expression.|},
        [
          {
            location =
              Prune.location "src/parser.ml" ~line:100 ~start_col:8 ~end_col:25;
            name = "parse_expression";
            warning_type = Unused_value;
            location_precision = Prune.Needs_enclosing_definition;
          };
        ] );
    ]
  in
  List.iter
    (fun (input, expected) ->
      let result = Prune.Warning.parse input in
      check (list warning_info) "Warning.parse edge cases" expected result)
    test_cases

let test_parse_warning_34_output () =
  (* Test warning 34 parsing *)
  let output =
    {|File "lib/types.ml", line 50, characters 0-24:
50 | type unused_record = {
     ^^^^^^^^^^^^^^^^^^^^^^^^
51 |   field1: int;
52 |   field2: string;
53 | }
Warning 34 [unused-type-declaration]: unused type unused_record.
File "lib/types.ml", line 60, characters 5-20:
60 | type unused_variant =
          ^^^^^^^^^^^^^^
61 |   | A
62 |   | B of int
Warning 34 [unused-type-declaration]: unused type unused_variant.|}
  in
  let result = Prune.Warning.parse output in
  let expected =
    [
      {
        location =
          Prune.location "lib/types.ml" ~line:50 ~start_col:0 ~end_col:24;
        name = "unused_record";
        warning_type = Unused_type;
        location_precision = Prune.Exact_definition;
      };
      {
        location =
          Prune.location "lib/types.ml" ~line:60 ~start_col:5 ~end_col:20;
        name = "unused_variant";
        warning_type = Unused_type;
        location_precision = Prune.Exact_definition;
      };
    ]
  in
  check (list warning_info) "parse warning 34" expected result

let test_type_detection () =
  (* Test that we correctly identify warning types *)
  let test_warning_32_output =
    {|File "test.ml", line 1, characters 4-8:
Warning 32 [unused-value-declaration]: unused value test.|}
  in
  let warnings = Prune.Warning.parse test_warning_32_output in
  match warnings with
  | [ warning ] ->
      check warning_type "warning type" Unused_value warning.warning_type
  | _ -> fail "Expected exactly one warning"

let test_type_preserved () =
  (* Ensure warning types are preserved through processing *)
  let output =
    {|File "test.ml", line 1, characters 0-10:
Warning 34 [unused-type-declaration]: unused type foo.
File "test.ml", line 2, characters 4-8:
Warning 32 [unused-value-declaration]: unused value bar.|}
  in
  let warnings = Prune.Warning.parse output in
  check int "number of warnings" 2 (List.length warnings);
  List.iter
    (fun (w : warning_info) ->
      match (w.name, w.warning_type) with
      | "foo", Unused_type -> () (* OK *)
      | "bar", Unused_value -> () (* OK *)
      | name, wtype ->
          failf "Unexpected warning: %s with type %s" name
            (Fmt.str "%a" Prune.pp_warning_type wtype))
    warnings

let test_parser_no_mix_errors () =
  (* Test that parser doesn't mix locations from different errors *)
  let output =
    {|File "lib/el.mli", line 16, characters 0-114:
16 | module Metric : sig
17 |   type t
..........
24 |   val reset : t -> unit
25 | end
Error: The implementation "lib/el.ml" does not match the interface "lib/el.cmi":
       The value `reset' is required but not provided
       File "lib/el.mli", line 24, characters 2-25: Expected declaration
File "lib/metrics.mli", line 1, characters 8-9:
1 | module X : module type of El.Metric
           ^
Error: Unbound module El
File "lib/brui.mli", line 1, characters 16-17:
1 | module Metric = X
                    ^
Error: Unbound module X
File "lib/brui.ml", line 1, characters 8-14:
1 | module Metric = Metrics.X
           ^^^^^^
Error: Unbound value Metric
File "bin/main.ml", line 2, characters 11-33:
2 | let () = Brui.Metric.compute ()
               ^^^^^^^^^^^^^^^^^^^^^^
Error: Unbound value Brui.Metric.compute
File "bin/main.ml", line 3, characters 11-31:
3 | let () = Brui.Metric.reset ()
               ^^^^^^^^^^^^^^^^^^^^
Error: Unbound value Brui.Metric.reset
File "lib/el.ml", line 19, characters 8-13:
19 |     let reset _ = print_endline "reset"
             ^^^^^
Warning 32 [unused-value-declaration]: unused value reset.|}
  in
  let warnings = Prune.Warning.parse output in
  (* Should only find the signature mismatch error and the warning 32 *)
  check int "number of warnings" 2 (List.length warnings);
  List.iter
    (fun (w : warning_info) ->
      match (w.name, w.warning_type, w.location.file) with
      | "`reset'", Signature_mismatch, "lib/el.mli" -> () (* OK *)
      | "reset", Unused_value, "lib/el.ml" -> () (* OK *)
      | _ ->
          failf "Unexpected warning: %s of type %s in %s" w.name
            (Fmt.str "%a" Prune.pp_warning_type w.warning_type)
            w.location.file)
    warnings

let test_parser_error_blocks () =
  (* Test that parser correctly handles error blocks without mixing
     information *)
  let output =
    {|File "lib/example.ml", line 10, characters 4-10:
10 | let helper = 42
         ^^^^^^
Error: Unbound value foo
File "lib/example.ml", line 20, characters 8-14:
20 |     let unused = 5
             ^^^^^^
Warning 32 [unused-value-declaration]: unused value unused.|}
  in
  let warnings = Prune.Warning.parse output in
  (* Should only find the warning 32, not the error *)
  check int "number of warnings" 1 (List.length warnings);
  match warnings with
  | [ warning ] ->
      check string "warning name" "unused" warning.name;
      check warning_type "warning type" Unused_value warning.warning_type;
      check int "warning line" 20 warning.location.start_line
  | _ -> fail "Expected exactly one warning"

let test_parser_multiline_warning_format () =
  (* Test that parser correctly handles multi-line warning format *)
  let output =
    {|File "lib/test.ml", line 5, characters 4-10:
Warning 32 [unused-value-declaration]: unused value foo.
File "lib/test.ml", line 10, characters 8-14:
Warning 32 [unused-value-declaration]: unused value bar.|}
  in
  let warnings = Prune.Warning.parse output in
  check int "number of warnings" 2 (List.length warnings);
  List.iter
    (fun (w : warning_info) ->
      match w.name with
      | "foo" -> check int "foo line" 5 w.location.start_line
      | "bar" -> check int "bar line" 10 w.location.start_line
      | _ -> failf "Unexpected warning name: %s" w.name)
    warnings

let test_parser_multiline_consecutive_warnings () =
  (* Test that parser correctly handles consecutive warnings in multi-line
     format with code display *)
  let output =
    {|File "lib/test.ml", line 5, characters 4-10:
5 |   let foo = 1
        ^^^
Warning 32 [unused-value-declaration]: unused value foo.
File "lib/test.ml", line 6, characters 4-10:
6 |   let bar = 2
        ^^^
Warning 32 [unused-value-declaration]: unused value bar.
File "lib/test.ml", line 7, characters 4-10:
7 |   let baz = 3
        ^^^
Warning 32 [unused-value-declaration]: unused value baz.|}
  in
  let warnings = Prune.Warning.parse output in
  check int "number of warnings" 3 (List.length warnings);
  let expected_warnings = [ ("foo", 5); ("bar", 6); ("baz", 7) ] in
  let sorted_warnings =
    List.sort
      (fun (a : warning_info) (b : warning_info) ->
        compare a.location.start_line b.location.start_line)
      warnings
  in
  List.iter2
    (fun (w : warning_info) (expected_name, expected_line) ->
      check string "warning name" expected_name w.name;
      check int "warning line" expected_line w.location.start_line)
    sorted_warnings expected_warnings

let test_parser_mixed_formats () =
  (* Test that parser handles mixed single-line and multi-line warning
     formats *)
  let output =
    {|File "lib/test.ml", line 5, characters 4-10:
5 |   let foo = 1
        ^^^
Warning 32 [unused-value-declaration]: unused value foo.
File "lib/test.ml", line 10, characters 8-14:
Warning 32 [unused-value-declaration]: unused value bar.
File "lib/test.ml", line 15, characters 2-8:
15 | let baz = 3
       ^^^
Warning 32 [unused-value-declaration]: unused value baz.|}
  in
  let warnings = Prune.Warning.parse output in
  check int "number of warnings" 3 (List.length warnings);
  List.iter
    (fun (w : warning_info) ->
      match w.name with
      | "foo" -> check int "foo line" 5 w.location.start_line
      | "bar" -> check int "bar line" 10 w.location.start_line
      | "baz" -> check int "baz line" 15 w.location.start_line
      | _ -> failf "Unexpected warning name: %s" w.name)
    warnings

let warning_69_mutable () =
  (* Test parsing warning 69 for mutable fields that are never mutated *)
  let output =
    {|File "lib/issue.ml", line 23, characters 2-31:
23 |   mutable tracks : string list;
       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Error (warning 69 [unused-field]): mutable record field tracks is never mutated.|}
  in
  let warnings = Prune.Warning.parse output in

  check int "number of warnings" 1 (List.length warnings);
  match warnings with
  | [ warning ] ->
      check string "warning name" "tracks" warning.name;
      check warning_type "warning type" Unnecessary_mutable warning.warning_type;
      check string "file" "lib/issue.ml" warning.location.file;
      check int "line" 23 warning.location.start_line;
      check int "start col" 2 warning.location.start_col;
      check int "end col" 31 warning.location.end_col
  | _ -> fail "Expected exactly one warning"

let warning_69_regular () =
  (* Test parsing warning 69 for regular unused fields *)
  let output =
    {|File "lib/test.ml", line 10, characters 4-20:
10 |   field1 : string;
       ^^^^^^^^^^^^^^^^
Warning 69 [unused-field]: record field field1 is never read.|}
  in
  let warnings = Prune.Warning.parse output in
  check int "number of warnings" 1 (List.length warnings);
  match warnings with
  | [ warning ] ->
      check string "warning name" "field1" warning.name;
      check warning_type "warning type" Unused_field warning.warning_type;
      check string "file" "lib/test.ml" warning.location.file;
      check int "line" 10 warning.location.start_line
  | _ -> fail "Expected exactly one warning"

let suite =
  ( "Warning.parse",
    [
      test_case "simple parsing" `Quick test_simple_parsing;
      test_case "basic parsing" `Quick test_parse_warnings;
      test_case "edge cases" `Quick warning_32_edge_cases;
      test_case "warning 34 parsing" `Quick test_parse_warning_34_output;
      test_case "warning type detection" `Quick test_type_detection;
      test_case "warning type preserved in processing" `Quick
        test_type_preserved;
      test_case "parser does not mix errors" `Quick test_parser_no_mix_errors;
      test_case "parser handles error blocks correctly" `Quick
        test_parser_error_blocks;
      test_case "parser multiline warning format" `Quick
        test_parser_multiline_warning_format;
      test_case "parser multiline consecutive warnings" `Quick
        test_parser_multiline_consecutive_warnings;
      test_case "parser mixed formats" `Quick test_parser_mixed_formats;
      test_case "warning 69 mutable field" `Quick warning_69_mutable;
      test_case "warning 69 regular field" `Quick warning_69_regular;
    ] )
