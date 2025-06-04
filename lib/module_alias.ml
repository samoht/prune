(* Module alias detection for OCaml code *)

module Log =
  (val Logs.src_log (Logs.Src.create "prune.module_alias") : Logs.LOG)

(* Helper for matching OCaml whitespace (space, tab, newline) *)
let ws = Re.(rep (alt [ space; char '\n'; char '\r' ]))
let ws1 = Re.(rep1 (alt [ space; char '\n'; char '\r' ]))

(* Helper for matching OCaml module names - start with uppercase or underscore,
   then alphanumeric/underscore/apostrophe *)
let module_name =
  Re.(
    seq
      [ alt [ rg 'A' 'Z'; char '_' ]; rep (alt [ alnum; char '_'; char '\'' ]) ])

(* Regular expressions for module alias detection *)
let module_type_alias_re =
  Re.compile
    Re.(
      seq
        [
          (* "module type" at the start of the line *)
          bos;
          str "module";
          ws1;
          str "type";
          ws1;
          (* Module type name *)
          group module_name;
          ws;
          str "=";
          ws;
          (* The aliased module *)
          group module_name;
          (* Optional .T or similar *)
          opt (seq [ char '.'; module_name ]);
        ])

let module_include_alias_re =
  Re.compile
    Re.(
      seq
        [
          (* Can be "sig" or start of line *)
          alt [ str "sig"; bos ];
          ws;
          (* "include module type of" *)
          str "include";
          ws1;
          str "module";
          ws1;
          str "type";
          ws1;
          str "of";
          ws1;
          (* The module being included *)
          group module_name;
        ])

(* Check if a module declaration in a .mli file is a module type alias *)
let is_module_type_alias content col =
  let lines = String.split_on_char '\n' content in
  (* Find the line containing this column position *)
  let rec find_line lines_before col_offset = function
    | [] -> None
    | line :: rest ->
        let line_length = String.length line + 1 in
        (* +1 for newline *)
        if col_offset < line_length then
          (* Found the line - check if it's an alias *)
          Some
            (Re.execp module_type_alias_re line
            || Re.execp module_include_alias_re line)
        else find_line (line :: lines_before) (col_offset - line_length) rest
  in
  match find_line [] col lines with None -> false | Some result -> result

(* Check if a multi-line module signature contains 'include module type of' *)
let is_multiline_module_type_alias ~cache file start_line end_line_opt =
  let max_lines_to_check = 20 in
  (* Reasonable limit for module signatures *)
  let end_line =
    match end_line_opt with
    | Some el -> min el (start_line + max_lines_to_check)
    | None -> start_line + max_lines_to_check
  in
  (* Collect lines and check for the pattern *)
  let rec collect_lines acc line_num =
    if line_num > end_line then String.concat " " (List.rev acc)
    else
      match Cache.get_line cache file line_num with
      | None -> String.concat " " (List.rev acc)
      | Some line -> collect_lines (String.trim line :: acc) (line_num + 1)
  in
  let content = collect_lines [] start_line in
  Re.execp module_include_alias_re content

(* Check if a module is an alias (interface files only) *)
let is_module_alias ~cache file symbol_kind loc content =
  match symbol_kind with
  | Types.Module when Filename.check_suffix file ".mli" ->
      (* For .mli files, check if it's a module type alias or uses 'include
         module type of' *)
      is_module_type_alias content loc.Types.start_col
      || is_multiline_module_type_alias ~cache file loc.Types.start_line
           (Some loc.Types.end_line)
  | _ -> false
