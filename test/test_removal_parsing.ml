(* Tests for removal.ml string-based parsing functions that need refactoring *)
open Alcotest
open Prune

(* Test helpers *)
let create_temp_file content =
  let temp_file = Filename.temp_file "prune_test" ".ml" in
  let oc = open_out temp_file in
  output_string oc content;
  close_out oc;
  temp_file

let read_file file =
  let ic = open_in file in
  let content = really_input_string ic (in_channel_length ic) in
  close_in ic;
  content

(* Tests for documentation comment removal behavior *)

let test_doc_comment_removal_single_line () =
  let content =
    {|(** This is a doc comment *)
let value = 42

(* Regular comment *)
let other = 33|}
  in
  let temp_file = create_temp_file content in

  (* Create a warning for the value to test doc comment removal *)
  let warning : Prune.warning_info =
    {
      location = location temp_file ~line:2 ~start_col:4 ~end_line:2 ~end_col:9;
      name = "value";
      warning_type = Prune.Unused_value;
      location_precision = Prune.Needs_enclosing_definition;
    }
  in

  let cache = Cache.create () in
  let result = Removal.remove_warnings ~cache "." [ warning ] in

  match result with
  | Error e ->
      Sys.remove temp_file;
      fail (Format.asprintf "Removal failed: %a" Prune.pp_error e)
  | Ok _ ->
      let new_content = read_file temp_file in
      Sys.remove temp_file;
      (* Check that both doc comment and value were removed *)
      check bool "doc comment removed" false
        (Re.execp (Re.compile (Re.str "(**")) new_content);
      check bool "value removed" false
        (Re.execp (Re.compile (Re.str "value")) new_content)

let test_doc_comment_removal_multi_line () =
  let content =
    {|(** This is a multi-line
    doc comment that spans
    several lines *)
let value = 42

(* Another comment *)
(** Doc for other *)
let other = 33|}
  in
  let temp_file = create_temp_file content in

  let warning : Prune.warning_info =
    {
      location = location temp_file ~line:4 ~start_col:4 ~end_line:4 ~end_col:9;
      name = "value";
      warning_type = Prune.Unused_value;
      location_precision = Prune.Needs_enclosing_definition;
    }
  in

  let cache = Cache.create () in
  let result = Removal.remove_warnings ~cache "." [ warning ] in

  match result with
  | Error e ->
      Sys.remove temp_file;
      fail (Format.asprintf "Removal failed: %a" Prune.pp_error e)
  | Ok _ ->
      let new_content = read_file temp_file in
      Sys.remove temp_file;
      (* Check that multi-line doc comment was removed along with value *)
      let lines = String.split_on_char '\n' new_content in
      let non_empty_lines = List.filter (fun l -> String.trim l <> "") lines in
      (* Should only have the regular comment and other value left *)
      check int "number of non-empty lines after removal" 3
        (List.length non_empty_lines)

let test_trailing_doc_comment_removal () =
  let content =
    {|let value = 42
(** Trailing doc comment *)

let other = 33|}
  in
  let temp_file = create_temp_file content in

  let warning : Prune.warning_info =
    {
      location = location temp_file ~line:1 ~start_col:4 ~end_line:1 ~end_col:9;
      name = "value";
      warning_type = Prune.Unused_value;
      location_precision = Prune.Needs_enclosing_definition;
    }
  in

  let cache = Cache.create () in
  let result = Removal.remove_warnings ~cache "." [ warning ] in

  match result with
  | Error e ->
      Sys.remove temp_file;
      fail (Format.asprintf "Removal failed: %a" Prune.pp_error e)
  | Ok _ ->
      let new_content = read_file temp_file in
      Sys.remove temp_file;
      (* The trailing doc comment belongs to "value" since there's no blank
         line *)
      check bool "trailing doc comment removed" false
        (Re.execp (Re.compile (Re.str "Trailing")) new_content);
      check bool "value removed" false
        (Re.execp (Re.compile (Re.str "value")) new_content);
      check bool "other value preserved" true
        (Re.execp (Re.compile (Re.str "other")) new_content)

let test_nested_comments_handling () =
  let content =
    {|(** Doc comment with (* nested comment *) inside *)
let value = 42|}
  in
  let temp_file = create_temp_file content in

  let warning : Prune.warning_info =
    {
      location = location temp_file ~line:2 ~start_col:4 ~end_line:2 ~end_col:9;
      name = "value";
      warning_type = Prune.Unused_value;
      location_precision = Prune.Needs_enclosing_definition;
    }
  in

  let cache = Cache.create () in
  let result = Removal.remove_warnings ~cache "." [ warning ] in

  match result with
  | Error e ->
      Sys.remove temp_file;
      fail (Format.asprintf "Removal failed: %a" Prune.pp_error e)
  | Ok _ ->
      (* Check if file was deleted (because it became empty) *)
      if Sys.file_exists temp_file then (
        let new_content = read_file temp_file in
        Sys.remove temp_file;
        (* The whole nested comment should be removed *)
        let trimmed = String.trim new_content in
        check string "all content removed" "" trimmed)
      else
        (* File was deleted because it became empty - this is expected *)
        ()

(* Test type definition replacement with empty record *)

let test_type_empty_record_replacement () =
  let content =
    {|type person = {
  name : string;
  age : int;
}

let make name age = { name; age }|}
  in
  let temp_file = create_temp_file content in

  (* Simulate removing all fields *)
  let warnings : Prune.warning_info list =
    [
      {
        location =
          location temp_file ~line:2 ~start_col:2 ~end_line:2 ~end_col:16;
        name = "name";
        warning_type = Prune.Unused_field;
        location_precision = Prune.Exact_statement;
      };
      {
        location =
          location temp_file ~line:3 ~start_col:2 ~end_line:3 ~end_col:13;
        name = "age";
        warning_type = Prune.Unused_field;
        location_precision = Prune.Exact_statement;
      };
    ]
  in

  let cache = Cache.create () in
  let result = Removal.remove_warnings ~cache "." warnings in

  match result with
  | Error e ->
      Sys.remove temp_file;
      fail (Format.asprintf "Removal failed: %a" Prune.pp_error e)
  | Ok _ ->
      let new_content = read_file temp_file in
      Sys.remove temp_file;
      (* When all fields are removed, the record should be replaced with unit *)
      check bool "type replaced with unit" true
        (Re.execp (Re.compile (Re.str "unit")) new_content)

(* Test that regular comments are not removed *)

let test_regular_comments_preserved () =
  let content =
    {|(* This is a regular comment *)
let value = 42

(* Another regular comment
   spanning multiple lines *)
let other = 33|}
  in
  let temp_file = create_temp_file content in

  let warning : Prune.warning_info =
    {
      location = location temp_file ~line:2 ~start_col:4 ~end_line:2 ~end_col:9;
      name = "value";
      warning_type = Prune.Unused_value;
      location_precision = Prune.Needs_enclosing_definition;
    }
  in

  let cache = Cache.create () in
  let result = Removal.remove_warnings ~cache "." [ warning ] in

  match result with
  | Error e ->
      Sys.remove temp_file;
      fail (Format.asprintf "Removal failed: %a" Prune.pp_error e)
  | Ok _ ->
      let new_content = read_file temp_file in
      Sys.remove temp_file;
      (* Regular comments that precede removed values should also be removed *)
      check bool "first regular comment removed with value" false
        (Re.execp (Re.compile (Re.str "This is a regular comment")) new_content);
      check bool
        "second regular comment preserved (not associated with removed value)"
        true
        (Re.execp (Re.compile (Re.str "Another regular comment")) new_content);
      check bool "value removed" false
        (Re.execp (Re.compile (Re.str "value = 42")) new_content)

let tests =
  ( "Removal parsing",
    [
      test_case "doc comment removal single line" `Quick
        test_doc_comment_removal_single_line;
      test_case "doc comment removal multi line" `Quick
        test_doc_comment_removal_multi_line;
      test_case "trailing doc comment removal" `Quick
        test_trailing_doc_comment_removal;
      test_case "nested comments handling" `Quick test_nested_comments_handling;
      test_case "type empty record replacement" `Quick
        test_type_empty_record_replacement;
      test_case "regular comments preserved" `Quick
        test_regular_comments_preserved;
    ] )
