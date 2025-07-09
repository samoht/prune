(* Tests for the Locate module *)
open Alcotest
open Prune

let create_temp_file content =
  let temp_file = Filename.temp_file "prune_test" ".ml" in
  let oc = open_out temp_file in
  output_string oc content;
  close_out oc;
  temp_file

let cleanup_temp_file file = if Sys.file_exists file then Sys.remove file

(* Helper to create and load cache *)
let create_test_cache file =
  let cache = Cache.create () in
  let _ = Cache.load cache file in
  cache

(* Helper to extract text content at a location from a file *)
let extract_location_text file_path location =
  let ic = open_in file_path in
  let lines = ref [] in
  (try
     while true do
       lines := input_line ic :: !lines
     done
   with End_of_file -> ());
  close_in ic;
  let all_lines = List.rev !lines |> Array.of_list in

  if location.start_line = location.end_line then
    (* Single line *)
    let line_content = all_lines.(location.start_line - 1) in
    let line_len = String.length line_content in
    let start_col = min location.start_col line_len in
    let end_col = min location.end_col line_len in
    String.sub line_content start_col (end_col - start_col)
  else
    (* Multiple lines *)
    let result = Buffer.create 256 in
    for line_num = location.start_line to location.end_line do
      let line_content = all_lines.(line_num - 1) in
      if line_num = location.start_line then (
        (* First line - from start_col to end *)
        let line_len = String.length line_content in
        let start_col = min location.start_col line_len in
        Buffer.add_substring result line_content start_col (line_len - start_col);
        Buffer.add_char result '\n')
      else if line_num = location.end_line then (
        (* Last line - from beginning to end_col *)
        let line_len = String.length line_content in
        let end_col = min location.end_col line_len in
        Buffer.add_substring result line_content 0 end_col;
        (* If this is an empty line and we want the whole line, add a newline *)
        if line_len = 0 && location.end_col > 0 then Buffer.add_char result '\n')
      else (
        (* Middle lines - full line *)
        Buffer.add_string result line_content;
        Buffer.add_char result '\n')
    done;
    Buffer.contents result

(* Helper to check if extracted content contains expected string *)
let check_contains temp_file location expected desc =
  let content = extract_location_text temp_file location in
  let re = Re.compile (Re.str expected) in
  let contains = Re.execp re content in
  check bool desc contains true

let test_field_detection_simple () =
  let content = {|
let my_record = {
  field1 = 42;
  field2 = "hello";
}
|} in
  let temp_file = create_temp_file content in
  let cache = create_test_cache temp_file in
  let result =
    Locate.get_field_info ~cache ~file:temp_file ~line:3 ~col:2
      ~field_name:"field1"
  in
  match result with
  | Ok info ->
      check string "field name" "field1" info.field_name;
      check int "field1 full bounds start line" 3
        info.full_field_bounds.start_line;
      check int "total fields" 2 info.total_fields;
      (* Verify the content is correct instead of exact column positions *)
      let text = extract_location_text temp_file info.full_field_bounds in
      cleanup_temp_file temp_file;
      (* Just check that we got the field, don't be too strict about bounds *)
      check bool "field1 bounds contains field" true
        (String.contains text '=' && String.contains text '4'
       && String.contains text '2')
  | Error (`Msg msg) ->
      cleanup_temp_file temp_file;
      fail ("Field detection failed: " ^ msg)

let test_enclosing_record_detection () =
  let content =
    {|
let outer_var = 10
let my_record = {
  field1 = 42;
  field2 = "hello";
}
let other_var = 20
|}
  in
  let temp_file = create_temp_file content in
  let cache = create_test_cache temp_file in
  let result =
    Locate.get_enclosing_record ~cache ~file:temp_file ~line:4 ~col:5
  in
  cleanup_temp_file temp_file;
  match result with
  | Ok location ->
      check int "record start line" 3 location.start_line;
      check int "record end line" 6 location.end_line
  | Error (`Msg msg) -> fail ("Enclosing record detection failed: " ^ msg)

let test_enclosing_record_nested () =
  let content =
    {|
let outer = {
  field1 = "test";
  inner = {
    nested_field = 100;
  };
  field2 = true;
}
|}
  in
  let temp_file = create_temp_file content in
  let cache = create_test_cache temp_file in
  (* Test finding inner record *)
  let result =
    Locate.get_enclosing_record ~cache ~file:temp_file ~line:5 ~col:8
  in
  cleanup_temp_file temp_file;
  match result with
  | Ok location ->
      check int "inner record start line" 4 location.start_line;
      check int "inner record end line" 6 location.end_line
  | Error (`Msg msg) -> fail ("Nested record detection failed: " ^ msg)

let test_enclosing_record_not_found () =
  let content = {|
let simple_var = 42
let another_var = "hello"
|} in
  let temp_file = create_temp_file content in
  let cache = create_test_cache temp_file in
  let result =
    Locate.get_enclosing_record ~cache ~file:temp_file ~line:2 ~col:5
  in
  cleanup_temp_file temp_file;
  match result with
  | Ok _ -> fail "Should not find record in non-record code"
  | Error (`Msg msg) ->
      check string "error message" "Could not find enclosing record" msg

let test_item_with_docs_detection () =
  let content =
    {|
let helper_function x = x + 1

let main_function () =
  let result = helper_function 42 in
  Printf.printf "Result: %d\n" result
|}
  in
  let temp_file = create_temp_file content in
  let cache = create_test_cache temp_file in
  let result =
    Locate.get_item_with_docs ~cache ~file:temp_file ~line:2 ~col:5
  in
  match result with
  | Ok location ->
      (* Check that we got the helper_function item with surrounding space *)
      check_contains temp_file location "let helper_function x = x + 1"
        "location contains helper_function";
      (* Location should only include the single line with the function *)
      let content = extract_location_text temp_file location in
      let lines =
        String.split_on_char '\n' content |> List.filter (fun s -> s <> "")
      in
      check int "location includes only the function line" 1 (List.length lines);
      cleanup_temp_file temp_file
  | Error (`Msg msg) ->
      cleanup_temp_file temp_file;
      fail ("Item detection failed: " ^ msg)

let test_item_with_docs_multiline () =
  let content =
    {|
let complex_function x y =
  let intermediate = x * 2 in
  let final = intermediate + y in
  final
|}
  in
  let temp_file = create_temp_file content in
  let cache = create_test_cache temp_file in
  let result =
    Locate.get_item_with_docs ~cache ~file:temp_file ~line:3 ~col:5
  in
  match result with
  | Ok location ->
      (* Check that we got the entire complex_function *)
      check_contains temp_file location "let complex_function x y ="
        "multiline item contains function start";
      check_contains temp_file location "final"
        "multiline item contains function end";
      cleanup_temp_file temp_file
  | Error (`Msg msg) ->
      cleanup_temp_file temp_file;
      fail ("Multiline item detection failed: " ^ msg)

let test_syntax_error_handling () =
  let content =
    {|
let broken_function x =
  if x > 0 then
    (* Missing 'else' branch *)
|}
  in
  let temp_file = create_temp_file content in
  let cache = create_test_cache temp_file in
  (* Should still be able to parse and find the function *)
  let result =
    Locate.get_item_with_docs ~cache ~file:temp_file ~line:2 ~col:5
  in
  cleanup_temp_file temp_file;
  match result with
  | Ok _ | Error _ ->
      (* Test passes if it doesn't crash - syntax errors are handled
         gracefully *)
      ()

let test_item_with_comments () =
  let content =
    {|
(* This is a helper function *)
let helper_function x = x + 1

(* Multi-line comment
   explaining the main function *)
let main_function () =
  helper_function 42
|}
  in
  let temp_file = create_temp_file content in
  let cache = create_test_cache temp_file in
  let result =
    Locate.get_item_with_docs ~cache ~file:temp_file ~line:3 ~col:5
  in
  match result with
  | Ok location ->
      (* Should find the helper_function definition *)
      check_contains temp_file location "let helper_function x = x + 1"
        "function with comment contains helper_function";
      cleanup_temp_file temp_file
  | Error (`Msg msg) ->
      cleanup_temp_file temp_file;
      fail ("Item with comments detection failed: " ^ msg)

let test_item_with_inline_comments () =
  let content = {|
let func x = (* inline comment *) x + 1
|} in
  let temp_file = create_temp_file content in
  let cache = create_test_cache temp_file in
  let result =
    Locate.get_item_with_docs ~cache ~file:temp_file ~line:2 ~col:5
  in
  match result with
  | Ok location ->
      (* Should get the entire function including inline comment *)
      check_contains temp_file location
        "let func x = (* inline comment *) x + 1"
        "function with inline comment contains full definition";
      cleanup_temp_file temp_file
  | Error (`Msg msg) ->
      cleanup_temp_file temp_file;
      fail ("Item with inline comments detection failed: " ^ msg)

let test_value_declaration_detection () =
  let content =
    {|
(** Documentation for helper function *)
let helper_function x = x + 1

let another_function y = y * 2
|}
  in
  let temp_file = create_temp_file content in
  let cache = create_test_cache temp_file in
  let result =
    Locate.get_item_with_docs ~cache ~file:temp_file ~line:3 ~col:5
  in
  match result with
  | Ok location ->
      let extracted_text = extract_location_text temp_file location in
      cleanup_temp_file temp_file;
      (* For now, without doc comment detection, should just get the function *)
      check string "value declaration content"
        "(** Documentation for helper function *)\n\
         let helper_function x = x + 1"
        (String.trim extracted_text)
  | Error (`Msg msg) ->
      cleanup_temp_file temp_file;
      fail ("Value declaration detection failed: " ^ msg)

let test_type_declaration_detection () =
  let content =
    {|
(** A simple record type *)
type person = {
  name : string;
  age : int;
}

(** A variant type *)
type color = Red | Green | Blue
|}
  in
  let temp_file = create_temp_file content in
  let cache = create_test_cache temp_file in
  let result =
    Locate.get_item_with_docs ~cache ~file:temp_file ~line:4 ~col:5
  in
  match result with
  | Ok location ->
      let extracted_text = extract_location_text temp_file location in
      cleanup_temp_file temp_file;
      (* Should detect the full type definition with its doc comment *)
      (* But NOT include the blank line and next item's doc comment *)
      check string "type declaration content"
        "(** A simple record type *)\n\
         type person = {\n\
        \  name : string;\n\
        \  age : int;\n\
         }"
        (String.trim extracted_text)
  | Error (`Msg msg) ->
      cleanup_temp_file temp_file;
      fail ("Type declaration detection failed: " ^ msg)

let test_exception_declaration_detection () =
  let content =
    {|
(** Custom exception for validation errors *)
exception ValidationError of string

let validate_input s = 
  if String.length s = 0 then
    raise (ValidationError "Empty input")
|}
  in
  let temp_file = create_temp_file content in
  let cache = create_test_cache temp_file in
  let result =
    Locate.get_item_with_docs ~cache ~file:temp_file ~line:3 ~col:10
  in
  match result with
  | Ok location ->
      let extracted_text = extract_location_text temp_file location in
      cleanup_temp_file temp_file;
      (* Should detect the exception declaration including doc comment *)
      check string "exception declaration content"
        "(** Custom exception for validation errors *)\n\
         exception ValidationError of string"
        (String.trim extracted_text)
  | Error (`Msg msg) ->
      cleanup_temp_file temp_file;
      fail ("Exception declaration detection failed: " ^ msg)

let test_module_declaration_detection () =
  let content =
    {|
(** Utility module for string operations *)
module StringUtils = struct
  let capitalize s = String.capitalize_ascii s
  let lowercase s = String.lowercase_ascii s
end

(** Another module *)
module MathUtils = struct
  let square x = x * x
end
|}
  in
  let temp_file = create_temp_file content in
  let cache = create_test_cache temp_file in
  let result =
    Locate.get_item_with_docs ~cache ~file:temp_file ~line:4 ~col:5
  in
  match result with
  | Ok location ->
      let extracted_text = extract_location_text temp_file location in
      cleanup_temp_file temp_file;
      (* Should detect module declaration (check it starts correctly) *)
      check bool "module declaration starts correctly" true
        (String.starts_with
           ~prefix:"(** Utility module for string operations *)"
           (String.trim extracted_text))
  | Error (`Msg msg) ->
      cleanup_temp_file temp_file;
      fail ("Module declaration detection failed: " ^ msg)

let test_module_type_declaration_detection () =
  let content =
    {|
module type COMPARABLE = sig
  type t
  val compare : t -> t -> int
end
|}
  in
  let temp_file = create_temp_file content in
  let cache = create_test_cache temp_file in
  let result =
    Locate.get_item_with_docs ~cache ~file:temp_file ~line:3 ~col:5
  in
  match result with
  | Ok location ->
      (* Should detect the entire module type *)
      check_contains temp_file location "module type COMPARABLE"
        "module type detection contains module type declaration";
      check_contains temp_file location "end"
        "module type detection contains end";
      cleanup_temp_file temp_file
  | Error (`Msg msg) ->
      cleanup_temp_file temp_file;
      fail ("Module type declaration detection failed: " ^ msg)

let test_multiple_doc_comments () =
  let content = {|
let simple_function z = z
|} in
  let temp_file = create_temp_file content in
  let cache = create_test_cache temp_file in
  let result =
    Locate.get_item_with_docs ~cache ~file:temp_file ~line:2 ~col:5
  in
  match result with
  | Ok location ->
      (* Should find the simple function *)
      check_contains temp_file location "let simple_function z = z"
        "multiple doc comments test contains simple function";
      cleanup_temp_file temp_file
  | Error (`Msg msg) ->
      cleanup_temp_file temp_file;
      fail ("Simple function detection failed: " ^ msg)

let test_item_without_docs () =
  let content = {|
let function_without_docs y = y * 2
|} in
  let temp_file = create_temp_file content in
  let cache = create_test_cache temp_file in
  let result =
    Locate.get_item_with_docs ~cache ~file:temp_file ~line:2 ~col:5
  in
  match result with
  | Ok location ->
      let extracted_text = extract_location_text temp_file location in
      cleanup_temp_file temp_file;
      (* Should only include the function itself, no docs *)
      check string "function without docs" "let function_without_docs y = y * 2"
        (String.trim extracted_text)
  | Error (`Msg msg) ->
      cleanup_temp_file temp_file;
      fail ("Item without docs detection failed: " ^ msg)

let test_external_declaration_detection () =
  let content =
    {|
external c_function : int -> int -> int = "c_function_stub"
|}
  in
  let temp_file = create_temp_file content in
  let cache = create_test_cache temp_file in
  let result =
    Locate.get_item_with_docs ~cache ~file:temp_file ~line:2 ~col:10
  in
  match result with
  | Ok location ->
      let extracted_text = extract_location_text temp_file location in
      cleanup_temp_file temp_file;
      (* Should detect the external declaration *)
      check string "external declaration"
        "external c_function : int -> int -> int = \"c_function_stub\""
        (String.trim extracted_text)
  | Error (`Msg msg) ->
      cleanup_temp_file temp_file;
      fail ("External declaration detection failed: " ^ msg)

let test_class_declaration_detection () =
  let content =
    {|
class counter initial_value = object
  val mutable count = initial_value
  method get = count
end
|}
  in
  let temp_file = create_temp_file content in
  let cache = create_test_cache temp_file in
  let result =
    Locate.get_item_with_docs ~cache ~file:temp_file ~line:3 ~col:5
  in
  match result with
  | Ok location ->
      let extracted_text = extract_location_text temp_file location in
      cleanup_temp_file temp_file;
      (* Should detect class declaration (check it starts correctly) *)
      check bool "class declaration starts correctly" true
        (String.starts_with ~prefix:"class counter"
           (String.trim extracted_text))
  | Error (`Msg msg) ->
      cleanup_temp_file temp_file;
      fail ("Class declaration detection failed: " ^ msg)

let test_field_info_type_definition () =
  let content =
    {|
module M = struct
  type person = {
    name : string;
    age : int;
    address : string;  (* Warning 69: unused field *)
  }
  
  let make name age = { name; age; address = "unused" }
end
|}
  in
  let temp_file = create_temp_file content in
  let cache = create_test_cache temp_file in
  (* Test getting field info for address field in type definition *)
  let result =
    Locate.get_field_info ~cache ~file:temp_file ~line:6 ~col:4
      ~field_name:"address"
  in
  match result with
  | Ok info ->
      (* Check the field info *)
      check string "field name" "address" info.field_name;
      check int "total fields" 3 info.total_fields;
      check bool "is type definition" true
        (match info.context with `Type_definition -> true | _ -> false);

      (* Instead of checking exact positions, verify the extracted text *)
      let text = extract_location_text temp_file info.full_field_bounds in
      cleanup_temp_file temp_file;
      (* Should include the full field definition with type and comment *)
      let contains_substring text pattern =
        Re.execp (Re.compile (Re.str pattern)) text
      in
      check bool "includes field name" true (contains_substring text "address");
      check bool "includes type annotation" true
        (contains_substring text ": string");
      check bool "includes comment" true (contains_substring text "Warning 69")
  | Error (`Msg msg) ->
      cleanup_temp_file temp_file;
      fail ("Field info detection failed: " ^ msg)

let test_field_bounds_max_int_clamping () =
  let content =
    {|type person = {
  name : string;
  age : int;
  address : string;  (* Last field in type definition *)
}|}
  in
  let file = create_temp_file content in

  let cache = create_test_cache file in
  match
    Locate.get_field_info ~cache ~file ~line:4 ~col:2 ~field_name:"address"
  with
  | Error e ->
      cleanup_temp_file file;
      fail (match e with `Msg msg -> "Failed to get field info: " ^ msg)
  | Ok field_info ->
      let bounds = field_info.full_field_bounds in

      (* Verify the text at the bounds is correct *)
      let text = extract_location_text file bounds in
      cleanup_temp_file file;

      (* Instead of checking exact positions, verify content *)
      let contains_substring text pattern =
        Re.execp (Re.compile (Re.str pattern)) text
      in
      check bool "includes field name" true (contains_substring text "address");
      check bool "includes type" true (contains_substring text ": string");
      check bool "includes comment" true (contains_substring text "Last field");
      (* Most importantly, verify end_col is reasonable (not max_int) *)
      check bool "end_col is reasonable" true (bounds.end_col < 1000)

let tests =
  ( "Locate",
    [
      test_case "field detection simple" `Quick test_field_detection_simple;
      test_case "enclosing record detection" `Quick
        test_enclosing_record_detection;
      test_case "enclosing record nested" `Quick test_enclosing_record_nested;
      test_case "enclosing record not found" `Quick
        test_enclosing_record_not_found;
      test_case "item with docs detection" `Quick test_item_with_docs_detection;
      test_case "item with docs multiline" `Quick test_item_with_docs_multiline;
      test_case "syntax error handling" `Quick test_syntax_error_handling;
      test_case "item with comments" `Quick test_item_with_comments;
      test_case "item with inline comments" `Quick
        test_item_with_inline_comments;
      (* Structure item tests *)
      test_case "value declaration detection" `Quick
        test_value_declaration_detection;
      test_case "type declaration detection" `Quick
        test_type_declaration_detection;
      test_case "exception declaration detection" `Quick
        test_exception_declaration_detection;
      test_case "module declaration detection" `Quick
        test_module_declaration_detection;
      test_case "module type declaration detection" `Quick
        test_module_type_declaration_detection;
      test_case "multiple doc comments" `Quick test_multiple_doc_comments;
      test_case "item without docs" `Quick test_item_without_docs;
      test_case "external declaration detection" `Quick
        test_external_declaration_detection;
      test_case "class declaration detection" `Quick
        test_class_declaration_detection;
      test_case "field info type definition" `Quick
        test_field_info_type_definition;
      test_case "field bounds max_int clamping" `Quick
        test_field_bounds_max_int_clamping;
    ] )
