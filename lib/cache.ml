(* File caching for efficient prune operations *)

open Bos
open Rresult

let src = Logs.Src.create "prune.cache" ~doc:"File caching"

module Log = (val Logs.src_log src : Logs.LOG)

(* Error helper functions *)
let err fmt = Fmt.kstr (fun e -> Error (`Msg e)) fmt
let err_file_not_cached file = err "File %s not found in cache" file

let err_ast_parse_syntax file e =
  err "Syntax error in %s: %s" file (Printexc.to_string e)

let err_ast_parse_failed file e =
  err "Failed to parse %s: %s" file (Printexc.to_string e)

type diff_entry = { line_num : int; old_content : string; new_content : string }

type ast_entry =
  | Implementation of Ppxlib.structure
  | Interface of Ppxlib.signature

type file_entry = {
  lines : string array;
  mutable diffs : diff_entry list;
  mutable ast : ast_entry option;
}

type t = {
  files : (string, file_entry) Hashtbl.t;
  mutable total_lines_removed : int;
}

(* Create a new cache *)
let create () = { files = Hashtbl.create 16; total_lines_removed = 0 }

(* Clear all entries from cache *)
let clear cache =
  Hashtbl.clear cache.files;
  cache.total_lines_removed <- 0

(* Track a line change for diff logging *)
let track_diff entry line_num old_content new_content =
  if old_content <> new_content then
    let new_diff = { line_num; old_content; new_content } in
    entry.diffs <- new_diff :: entry.diffs

let get_or_create cache file content =
  let lines_list = String.split_on_char '\n' content in
  let lines = Array.of_list lines_list in
  let entry = { lines; diffs = []; ast = None } in
  Hashtbl.replace cache.files file entry;
  entry

(* Load a file into cache if not already present *)
let load cache file =
  match Hashtbl.find_opt cache.files file with
  | Some _ -> Ok ()
  | None -> (
      match OS.File.read (Fpath.v file) with
      | Error (`Msg msg) -> Error (`Msg msg)
      | Ok content ->
          let (_ : file_entry) = get_or_create cache file content in
          Ok ())

(* Get a single line from cache *)
let get_line cache file line_num =
  match Hashtbl.find_opt cache.files file with
  | None -> None
  | Some entry ->
      if line_num > 0 && line_num <= Array.length entry.lines then
        Some entry.lines.(line_num - 1)
      else None

(* Replace a line in the cache *)
let replace_line cache file line_num new_content =
  match Hashtbl.find_opt cache.files file with
  | None -> Log.warn (fun m -> m "replace_line: file %s not in cache" file)
  | Some entry ->
      if line_num > 0 && line_num <= Array.length entry.lines then (
        let idx = line_num - 1 in
        let old_content = entry.lines.(idx) in
        Log.debug (fun m ->
            m "replace_line %s:%d '%s' -> '%s'" file line_num old_content
              new_content);
        track_diff entry line_num old_content new_content;
        (* Track lines removed *)
        if old_content <> "" && new_content = "" then
          cache.total_lines_removed <- cache.total_lines_removed + 1;
        entry.lines.(idx) <- new_content;
        (* Clear AST cache since file was modified *)
        entry.ast <- None)
      else
        Log.warn (fun m ->
            m "replace_line: line %d out of bounds for %s" line_num file)

(* Clear a line (replace with empty string) *)
let clear_line cache file line_num = replace_line cache file line_num ""

(* Get the number of lines in a file *)
let get_line_count cache file =
  match Hashtbl.find_opt cache.files file with
  | None -> None
  | Some entry -> Some (Array.length entry.lines)

(* Check if a file has any changes *)
let has_changes cache file =
  match Hashtbl.find_opt cache.files file with
  | None -> false
  | Some entry -> entry.diffs <> []

(* Count the number of lines removed (cleared) across all files *)
let count_lines_removed cache = cache.total_lines_removed

(* Check if a file is effectively empty (only blank lines) *)
let is_file_empty cache file =
  match Hashtbl.find_opt cache.files file with
  | None -> false
  | Some entry ->
      (* A file is empty if all lines are blank *)
      Array.for_all (fun line -> String.trim line = "") entry.lines

(* Parse AST from entry content *)
let parse_ast_for_entry file entry =
  let content = String.concat "\n" (Array.to_list entry.lines) in
  let lexbuf = Lexing.from_string content in
  Location.init lexbuf file;
  try
    if Filename.check_suffix file ".mli" then (
      let ast = Ppxlib.Parse.interface lexbuf in
      entry.ast <- Some (Interface ast);
      Ok ())
    else
      let ast = Ppxlib.Parse.implementation lexbuf in
      entry.ast <- Some (Implementation ast);
      Ok ()
  with
  | Syntaxerr.Error _ as e -> err_ast_parse_syntax file e
  | e -> err_ast_parse_failed file e

(* Get AST from cache, parsing if necessary *)
let get_ast cache file =
  match Hashtbl.find_opt cache.files file with
  | None -> err_file_not_cached file
  | Some entry -> (
      match entry.ast with
      | Some ast -> Ok ast
      | None -> (
          match parse_ast_for_entry file entry with
          | Ok () -> (
              match entry.ast with
              | Some ast -> Ok ast
              | None -> err "Failed to cache AST for %s" file)
          | Error e -> Error e))

(* Log diffs for debugging *)
let log_diffs file diffs =
  Log.debug (fun m -> m "Found %d diffs for file %s" (List.length diffs) file);
  List.iter
    (fun diff ->
      Log.debug (fun m ->
          m "  Line %d: '%s' -> '%s'" diff.line_num diff.old_content
            diff.new_content))
    (List.rev diffs)

(* Write file content to disk *)
let write_file_content file entry =
  let result =
    OS.File.with_output (Fpath.v file)
      (fun oc () ->
        (* Write all lines, preserving line numbers *)
        Array.iteri
          (fun i line ->
            oc (Some (Bytes.of_string line, 0, String.length line));
            if i < Array.length entry.lines - 1 then
              oc (Some (Bytes.of_string "\n", 0, 1)))
          entry.lines;
        Ok ())
      ()
  in
  match result with
  | Ok (Ok ()) ->
      Log.debug (fun m -> m "Successfully flushed file to disk: %s" file);
      Ok ()
  | Ok (Error (`Msg msg)) | Error (`Msg msg) ->
      Log.err (fun m -> m "Failed to write file %s: %s" file msg);
      Error (`Msg msg)

(* Write file to disk *)
let write cache file =
  match Hashtbl.find_opt cache.files file with
  | None -> err_file_not_cached file
  | Some entry -> (
      (* Fail hard if no diffs - this shouldn't happen *)
      if entry.diffs = [] then
        failwith
          (Printf.sprintf
             "BUG: Attempted to write file %s with no changes. This indicates \
              a logic error in the removal process."
             file);

      (* Check if file exists before attempting to write *)
      let file_path = Fpath.v file in
      match OS.Path.exists file_path with
      | Error (`Msg msg) -> err "Failed to check file existence: %s" msg
      | Ok false -> err "File %s does not exist" file
      | Ok true ->
          Log.info (fun m -> m "Writing modified content to disk: %s" file);
          log_diffs file entry.diffs;
          (* Clear diffs after writing *)
          entry.diffs <- [];
          write_file_content file entry)
