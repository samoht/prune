(* Unit tests for the Removal module *)
open Alcotest
open Prune

let temp_file content =
  let file = Filename.temp_file "prune_test" ".ml" in
  let oc = open_out file in
  output_string oc content;
  close_out oc;
  file

let read_file file =
  let ic = open_in file in
  let content = really_input_string ic (in_channel_length ic) in
  close_in ic;
  content

(* Helper to check field presence in type definition *)
let check_field_in_type field_name content =
  let field_re =
    Re.(
      compile
        (seq
           [
             str field_name;
             rep any;
             str ":";
             rep any;
             rep (compl [ char ';'; char '}' ]);
           ]))
  in
  Re.execp field_re content

(* Helper to check field usage in record construction *)
let check_field_usage field_name value content =
  let usage_re =
    Re.(compile (seq [ str field_name; rep any; str "="; rep any; str value ]))
  in
  Re.execp usage_re content

(* Field removal tests *)
let test_unused_field_removal () =
  let content =
    {|
type person = {
  name : string;
  age : int;
  address : string;  (* Warning 69: unused field *)
}

let make name age = { name; age; address = "unused" }
|}
  in
  let temp_file = temp_file content in

  (* Create a fake warning for the unused field *)
  let warning : Prune.warning_info =
    {
      location = location temp_file ~line:5 ~start_col:2 ~end_line:5 ~end_col:19;
      name = "address";
      warning_type = Prune.Unused_field;
      location_precision = Prune.Exact_statement;
    }
  in

  (* Test removing the unused field *)
  let cache = Cache.v () in
  let result =
    Removal.remove_unused_exports ~cache "." temp_file
      [ { name = "address"; kind = Field; location = warning.location } ]
  in

  match result with
  | Error e ->
      Sys.remove temp_file;
      failf "Field removal failed: %a" Prune.pp_error e
  | Ok () ->
      let new_content = read_file temp_file in
      Sys.remove temp_file;
      Fmt.pr "Content after removal:\n%s\n" new_content;
      (* Check that the field was removed from the type definition *)
      check bool "field removed from type (replaced with spaces)" false
        (check_field_in_type "address" new_content);
      (* The field usage in record construction should still be there *)
      check bool "field usage still present" true
        (check_field_usage "address" "\"unused\"" new_content)

let test_field_removal_preserves_fields () =
  let content =
    {|
type config = {
  host : string;
  port : int;
  debug : bool;  (* To be removed *)
  timeout : float;
}
|}
  in
  let temp_file = temp_file content in

  let warning : Prune.warning_info =
    {
      location = location temp_file ~line:5 ~start_col:2 ~end_line:5 ~end_col:16;
      name = "debug";
      warning_type = Prune.Unused_field;
      location_precision = Prune.Exact_statement;
    }
  in

  let cache = Cache.v () in
  let result =
    Removal.remove_unused_exports ~cache "." temp_file
      [ { name = "debug"; kind = Field; location = warning.location } ]
  in

  match result with
  | Error e ->
      Sys.remove temp_file;
      failf "Field removal failed: %a" Prune.pp_error e
  | Ok () ->
      let new_content = read_file temp_file in
      Sys.remove temp_file;
      (* Check that other fields are preserved *)
      let host_re = Re.(compile (str "host")) in
      let port_re = Re.(compile (str "port")) in
      let timeout_re = Re.(compile (str "timeout")) in
      let debug_re = Re.(compile (str "debug")) in
      check bool "host field preserved" true (Re.execp host_re new_content);
      check bool "port field preserved" true (Re.execp port_re new_content);
      check bool "timeout field preserved" true
        (Re.execp timeout_re new_content);
      check bool "debug field removed" false (Re.execp debug_re new_content)

(* Documentation comment removal tests *)
let test_doc_comment_single_line () =
  let content =
    {|(** This is a doc comment *)
let value = 42

(* Regular comment *)
let other = 33|}
  in
  let temp_file = temp_file content in

  (* Create a warning for the value to test doc comment removal *)
  let warning : Prune.warning_info =
    {
      location = location temp_file ~line:2 ~start_col:4 ~end_line:2 ~end_col:9;
      name = "value";
      warning_type = Prune.Unused_value;
      location_precision = Prune.Needs_enclosing_definition;
    }
  in

  let cache = Cache.v () in
  let result = Removal.remove_warnings ~cache "." [ warning ] in

  match result with
  | Error e ->
      Sys.remove temp_file;
      failf "Removal failed: %a" Prune.pp_error e
  | Ok _ ->
      let new_content = read_file temp_file in
      Sys.remove temp_file;
      (* Check that both doc comment and value were removed *)
      check bool "doc comment removed" false
        (Re.execp (Re.compile (Re.str "(**")) new_content);
      check bool "value removed" false
        (Re.execp (Re.compile (Re.str "value")) new_content)

let test_type_empty_record_replacement () =
  let content =
    {|type person = {
  name : string;
  age : int;
}

let make name age = { name; age }|}
  in
  let temp_file = temp_file content in

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

  let cache = Cache.v () in
  let result = Removal.remove_warnings ~cache "." warnings in

  match result with
  | Error e ->
      Sys.remove temp_file;
      failf "Removal failed: %a" Prune.pp_error e
  | Ok _ ->
      let new_content = read_file temp_file in
      Sys.remove temp_file;
      (* When all fields are removed, the record should be replaced with unit *)
      check bool "type replaced with unit" true
        (Re.execp (Re.compile (Re.str "unit")) new_content)

let suite =
  ( "removal",
    [
      test_case "unused field removal" `Quick test_unused_field_removal;
      test_case "field removal preserves other fields" `Quick
        test_field_removal_preserves_fields;
      test_case "doc comment removal single line" `Quick
        test_doc_comment_single_line;
      test_case "type empty record replacement" `Quick
        test_type_empty_record_replacement;
    ] )
