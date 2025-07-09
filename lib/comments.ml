(* Source comment scanning utilities for comments not in the AST

   This module handles detection of source-level comments (* ... *) that are not
   part of the OCaml AST. Doc comments (** ... *) attached to items become
   attributes and are handled through the AST, but floating doc comments and
   regular comments need this scanner.

   TODO: Remove this module once OCaml parser includes all comments in AST *)

module Log = (val Logs.src_log (Logs.Src.create "prune.comments") : Logs.LOG)

(* Check if a string starts with a prefix *)
let starts_with s prefix =
  String.length s >= String.length prefix
  && String.sub s 0 (String.length prefix) = prefix

(* Check if a line contains comment end marker *)
let line_contains_comment_end line =
  let rec check i =
    if i >= String.length line - 1 then false
    else if line.[i] = '*' && line.[i + 1] = ')' then true
    else check (i + 1)
  in
  check 0

(* Check if a line is a comment line *)
let is_comment_line line =
  let trimmed = String.trim line in
  starts_with trimmed "(*"

(* Check if a line is empty *)
let is_empty_line line = String.trim line = ""

(* Find the start of comments (both doc and regular) preceding a given line *)
let find_preceding_comment_start cache file start_line_idx =
  if start_line_idx <= 0 then start_line_idx
  else
    let rec scan_backwards line_idx in_comment_block =
      if line_idx < 0 then 0
      else
        match Cache.get_line cache file (line_idx + 1) with
        | None -> line_idx + 1
        | Some line ->
            if is_empty_line line then
              (* Empty line - might be separator or part of comment block *)
              if in_comment_block then scan_backwards (line_idx - 1) true
              else line_idx + 1 (* Stop here - this is a separator *)
            else if is_comment_line line then
              (* Found a comment - keep scanning *)
              scan_backwards (line_idx - 1) true
            else if line_contains_comment_end line && not (is_comment_line line)
            then
              (* Multi-line comment end - need to find start *)
              let rec find_multi_start idx depth =
                if idx < 0 then 0
                else
                  match Cache.get_line cache file (idx + 1) with
                  | None -> idx + 1
                  | Some l ->
                      let rec count_markers i starts ends =
                        if i >= String.length l - 1 then (starts, ends)
                        else if l.[i] = '(' && l.[i + 1] = '*' then
                          count_markers (i + 2) (starts + 1) ends
                        else if l.[i] = '*' && l.[i + 1] = ')' then
                          count_markers (i + 2) starts (ends + 1)
                        else count_markers (i + 1) starts ends
                      in
                      let starts, ends = count_markers 0 0 0 in
                      let new_depth = depth + ends - starts in
                      if new_depth <= 0 && starts > 0 then idx
                      else find_multi_start (idx - 1) new_depth
              in
              find_multi_start (line_idx - 1) 0
            else
              (* Hit code - stop *)
              line_idx + 1
    in
    scan_backwards (start_line_idx - 1) false

(* Find trailing comments after a given line *)
let find_trailing_comment_end cache file end_line_idx =
  Log.debug (fun m ->
      m "find_trailing_comment_end: file=%s end_line_idx=%d" file end_line_idx);
  match Cache.get_line_count cache file with
  | None -> end_line_idx
  | Some max_lines ->
      if end_line_idx >= max_lines then end_line_idx
      else
        let scan_forward line_idx =
          if line_idx >= max_lines then line_idx
          else
            match Cache.get_line cache file (line_idx + 1) with
            | None ->
                Log.debug (fun m ->
                    m "  scan_forward: no line at %d, returning %d"
                      (line_idx + 1) line_idx);
                line_idx
            | Some line ->
                Log.debug (fun m ->
                    m "  scan_forward: line %d = '%s'" (line_idx + 1) line);
                if is_empty_line line then
                  (* Blank line - stop here, comments after blank lines belong
                     to next item *)
                  line_idx
                else if is_comment_line line then
                  (* Comment immediately follows - this is a trailing comment *)
                  if line_contains_comment_end line then
                    line_idx + 1 (* Single-line comment *)
                  else
                    (* Multi-line comment - find where it ends *)
                    let rec find_end idx =
                      if idx >= max_lines - 1 then max_lines - 1
                      else
                        match Cache.get_line cache file (idx + 1) with
                        | None -> idx
                        | Some l ->
                            if line_contains_comment_end l then idx + 1
                            else find_end (idx + 1)
                    in
                    find_end line_idx
                else
                  (* Non-comment line - stop here *)
                  line_idx
        in
        scan_forward end_line_idx

(* Extend location bounds to include source-level comments *)
let extend_location_with_comments cache file location =
  (* Find preceding comments *)
  let start_with_comments =
    find_preceding_comment_start cache file (location.Types.start_line - 1) + 1
  in
  (* Find trailing comments *)
  let end_with_comments =
    find_trailing_comment_end cache file location.Types.end_line
  in
  Log.debug (fun m ->
      m "extend_location_with_comments: file=%s original %d-%d, extended %d-%d"
        file location.Types.start_line location.Types.end_line
        start_with_comments end_with_comments);
  Types.extend location ~start_line:start_with_comments
    ~end_line:end_with_comments
