(* Tests for the cache module *)
open Alcotest
open Prune

let create_temp_file content =
  let temp_file = Filename.temp_file "cache_test" ".txt" in
  let oc = open_out temp_file in
  output_string oc content;
  close_out oc;
  temp_file

let read_file file =
  let ic = open_in file in
  let content = really_input_string ic (in_channel_length ic) in
  close_in ic;
  content

let test_create_and_clear () =
  let cache = Cache.create () in
  let temp_file = create_temp_file "line1\nline2\nline3" in

  (* Load file into cache *)
  (match Cache.load cache temp_file with
  | Ok () -> ()
  | Error (`Msg msg) -> fail msg);

  (* Verify file is loaded *)
  check (option string) "line 1" (Some "line1")
    (Cache.get_line cache temp_file 1);
  check (option string) "line 2" (Some "line2")
    (Cache.get_line cache temp_file 2);

  (* Clear cache *)
  Cache.clear cache;

  (* Verify cache is empty *)
  check (option string) "after clear" None (Cache.get_line cache temp_file 1);

  Sys.remove temp_file

let test_load_and_get_line () =
  let cache = Cache.create () in
  let content = "first line\nsecond line\nthird line" in
  let temp_file = create_temp_file content in

  (* Test get_line before loading *)
  check (option string) "before load" None (Cache.get_line cache temp_file 1);

  (* Load file *)
  (match Cache.load cache temp_file with
  | Ok () -> ()
  | Error (`Msg msg) -> fail msg);

  (* Test get_line after loading *)
  check (option string) "line 1" (Some "first line")
    (Cache.get_line cache temp_file 1);
  check (option string) "line 2" (Some "second line")
    (Cache.get_line cache temp_file 2);
  check (option string) "line 3" (Some "third line")
    (Cache.get_line cache temp_file 3);

  (* Test out of bounds *)
  check (option string) "line 0" None (Cache.get_line cache temp_file 0);
  check (option string) "line 4" None (Cache.get_line cache temp_file 4);

  Sys.remove temp_file

let test_replace_line () =
  let cache = Cache.create () in
  let content = "AAA\nBBB\nCCC" in
  let temp_file = create_temp_file content in

  (* Load file *)
  (match Cache.load cache temp_file with
  | Ok () -> ()
  | Error (`Msg msg) -> fail msg);

  (* Replace line 2 *)
  Cache.replace_line cache temp_file 2 "XXX";

  (* Verify replacement *)
  check (option string) "line 1 unchanged" (Some "AAA")
    (Cache.get_line cache temp_file 1);
  check (option string) "line 2 replaced" (Some "XXX")
    (Cache.get_line cache temp_file 2);
  check (option string) "line 3 unchanged" (Some "CCC")
    (Cache.get_line cache temp_file 3);

  (* Test out of bounds replace *)
  Cache.replace_line cache temp_file 0 "invalid";
  Cache.replace_line cache temp_file 4 "invalid";

  (* Lines should be unchanged *)
  check (option string) "after invalid replace" (Some "XXX")
    (Cache.get_line cache temp_file 2);

  Sys.remove temp_file

let test_clear_line () =
  let cache = Cache.create () in
  let content = "line1\nline2\nline3" in
  let temp_file = create_temp_file content in

  (* Load file *)
  (match Cache.load cache temp_file with
  | Ok () -> ()
  | Error (`Msg msg) -> fail msg);

  (* Clear line 2 *)
  Cache.clear_line cache temp_file 2;

  (* Verify clearing *)
  check (option string) "line 1 unchanged" (Some "line1")
    (Cache.get_line cache temp_file 1);
  check (option string) "line 2 cleared" (Some "")
    (Cache.get_line cache temp_file 2);
  check (option string) "line 3 unchanged" (Some "line3")
    (Cache.get_line cache temp_file 3);

  Sys.remove temp_file

let test_get_line_count () =
  let cache = Cache.create () in

  (* Test non-existent file *)
  check (option int) "non-existent file" None
    (Cache.get_line_count cache "nonexistent.txt");

  let content = "one\ntwo\nthree\nfour" in
  let temp_file = create_temp_file content in

  (* Load file *)
  (match Cache.load cache temp_file with
  | Ok () -> ()
  | Error (`Msg msg) -> fail msg);

  (* Check line count *)
  check (option int) "line count" (Some 4)
    (Cache.get_line_count cache temp_file);

  (* Test empty file *)
  let empty_file = create_temp_file "" in
  (match Cache.load cache empty_file with
  | Ok () -> ()
  | Error (`Msg msg) -> fail msg);
  check (option int) "empty file" (Some 1)
    (Cache.get_line_count cache empty_file);

  Sys.remove temp_file;
  Sys.remove empty_file

let test_write_with_changes () =
  let cache = Cache.create () in
  let content = "original1\noriginal2\noriginal3" in
  let temp_file = create_temp_file content in

  (* Load file *)
  (match Cache.load cache temp_file with
  | Ok () -> ()
  | Error (`Msg msg) -> fail msg);

  (* Make changes *)
  Cache.replace_line cache temp_file 1 "modified1";
  Cache.clear_line cache temp_file 2;
  Cache.replace_line cache temp_file 3 "modified3";

  (* Write to disk *)
  (match Cache.write cache temp_file with
  | Ok () -> ()
  | Error (`Msg msg) -> fail msg);

  (* Read file and verify *)
  let new_content = read_file temp_file in
  check string "written content" "modified1\n\nmodified3" new_content;

  Sys.remove temp_file

let test_write_without_changes_fails () =
  let cache = Cache.create () in
  let content = "line1\nline2" in
  let temp_file = create_temp_file content in

  (* Load file *)
  (match Cache.load cache temp_file with
  | Ok () -> ()
  | Error (`Msg msg) -> fail msg);

  (* Try to write without making changes - should fail *)
  let write_result =
    try
      let _ = Cache.write cache temp_file in
      false
    with Failure msg ->
      (* Check the error message *)
      check bool "error message contains BUG" true
        (String.starts_with ~prefix:"BUG: Attempted to write file" msg);
      true
  in

  check bool "write without changes fails" true write_result;

  Sys.remove temp_file

let test_no_change_tracking () =
  let cache = Cache.create () in
  let content = "AAA\nBBB\nCCC" in
  let temp_file = create_temp_file content in

  (* Load file *)
  (match Cache.load cache temp_file with
  | Ok () -> ()
  | Error (`Msg msg) -> fail msg);

  (* Replace with same content - should not track as diff *)
  Cache.replace_line cache temp_file 2 "BBB";

  (* Try to write - should fail since no actual changes *)
  let write_result =
    try
      let _ = Cache.write cache temp_file in
      false
    with Failure _ -> true
  in

  check bool "write with no-op change fails" true write_result;

  Sys.remove temp_file

let test_multiple_files () =
  let cache = Cache.create () in
  let file1 = create_temp_file "file1_line1\nfile1_line2" in
  let file2 = create_temp_file "file2_line1\nfile2_line2" in

  (* Load both files *)
  (match Cache.load cache file1 with
  | Ok () -> ()
  | Error (`Msg msg) -> fail msg);

  (match Cache.load cache file2 with
  | Ok () -> ()
  | Error (`Msg msg) -> fail msg);

  (* Modify different files *)
  Cache.replace_line cache file1 1 "modified_file1";
  Cache.replace_line cache file2 2 "modified_file2";

  (* Check independence *)
  check (option string) "file1 line 1" (Some "modified_file1")
    (Cache.get_line cache file1 1);
  check (option string) "file1 line 2" (Some "file1_line2")
    (Cache.get_line cache file1 2);
  check (option string) "file2 line 1" (Some "file2_line1")
    (Cache.get_line cache file2 1);
  check (option string) "file2 line 2" (Some "modified_file2")
    (Cache.get_line cache file2 2);

  Sys.remove file1;
  Sys.remove file2

let tests =
  ( "Cache",
    [
      test_case "create and clear" `Quick test_create_and_clear;
      test_case "load and get_line" `Quick test_load_and_get_line;
      test_case "replace_line" `Quick test_replace_line;
      test_case "clear_line" `Quick test_clear_line;
      test_case "get_line_count" `Quick test_get_line_count;
      test_case "write with changes" `Quick test_write_with_changes;
      test_case "write without changes fails" `Quick
        test_write_without_changes_fails;
      test_case "no change tracking" `Quick test_no_change_tracking;
      test_case "multiple files" `Quick test_multiple_files;
    ] )
