(* Unit tests for the Comments module - tested via Removal *)
open Alcotest
open Prune

(* Helper to read file *)
let read_file file =
  let ic = open_in file in
  let content = really_input_string ic (in_channel_length ic) in
  close_in ic;
  content

(* Helper to check if a string contains a substring *)
let contains s sub =
  let rec search i =
    if i + String.length sub > String.length s then false
    else if String.sub s i (String.length sub) = sub then true
    else search (i + 1)
  in
  search 0

(* Helper to create a temporary test file *)
let temp_file content =
  let file = Filename.temp_file "test_comments" ".mli" in
  let oc = open_out file in
  output_string oc content;
  close_out oc;
  file

(* Test the trailing comment detection logic through actual removal *)
let test_trailing_comment_blank_line () =
  let cache = Cache.v () in

  (* Create test content with comments separated by blank lines *)
  let content =
    {|val foo : int -> int
(** Trailing comment for foo *)

(** Leading comment for bar *)
val bar : string -> string|}
  in

  let temp_file = temp_file content in

  (* Create a warning for foo to test comment removal *)
  let warning : warning_info =
    {
      location = location temp_file ~line:1 ~start_col:0 ~end_line:1 ~end_col:20;
      name = "foo";
      warning_type = Unused_value;
      location_precision = Needs_enclosing_definition;
    }
  in

  (* Remove the warning *)
  (match Removal.remove_warnings ~cache "." [ warning ] with
  | Ok _ -> ()
  | Error e ->
      Sys.remove temp_file;
      failf "Removal failed: %a" pp_error e);

  (* Check what was removed *)
  let new_content = read_file temp_file in
  Sys.remove temp_file;

  (* Print the content for debugging *)
  Fmt.pr "\nNew content:\n%s\n" new_content;

  (* The blank line stops the trailing comment scan, so the leading comment for
     bar is NOT included in foo's removal and remains in the file *)
  check bool "Leading comment for bar preserved (not part of foo)" true
    (contains new_content "Leading comment for bar");
  check bool "bar declaration should be preserved" true
    (contains new_content "val bar")

let test_leading_comment_preserved () =
  let cache = Cache.v () in

  (* Create test content similar to the real-world example *)
  let content =
    {|type t = string

type unused = int
(** This doc comment should be removed with unused *)

val compute : t -> t
(** This doc comment should NOT be removed because compute is not being removed *)|}
  in

  let temp_file = temp_file content in

  (* Create a warning only for the unused type *)
  let warning : warning_info =
    {
      location = location temp_file ~line:3 ~start_col:0 ~end_line:3 ~end_col:17;
      name = "unused";
      warning_type = Unused_type;
      location_precision = Needs_enclosing_definition;
    }
  in

  (* Remove the warning *)
  (match Removal.remove_warnings ~cache "." [ warning ] with
  | Ok _ -> ()
  | Error e ->
      Sys.remove temp_file;
      failf "Removal failed: %a" pp_error e);

  (* Check what was removed *)
  let new_content = read_file temp_file in
  Sys.remove temp_file;

  (* The doc comment for compute should still be there *)
  check bool "Doc comment for compute should be preserved" true
    (contains new_content "should NOT be removed");
  check bool "compute declaration should be preserved" true
    (contains new_content "val compute")

let suite =
  [
    test_case "trailing comment stops at blank line" `Quick
      test_trailing_comment_blank_line;
    test_case "leading comment not removed for used item" `Quick
      test_leading_comment_preserved;
  ]
