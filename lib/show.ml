open Types

type format = Cli | Html

let pp_symbol_with_count fmt (symbol : symbol_info) count =
  Fmt.pf fmt "%s %s (%d occurrences)"
    (string_of_symbol_kind symbol.kind)
    symbol.name count

let pp_location_link fmt loc =
  Fmt.pf fmt "%s:%d:%d" loc.file loc.start_line loc.start_col

let group_by_file occurrences =
  List.fold_left
    (fun acc occ ->
      let file = occ.symbol.location.file in
      let existing = try List.assoc file acc with Not_found -> [] in
      (file, occ :: existing) :: List.remove_assoc file acc)
    [] occurrences

let group_by_symbol occurrences =
  List.fold_left
    (fun acc occ ->
      let key = (occ.symbol.name, occ.symbol.kind) in
      let existing = try List.assoc key acc with Not_found -> [] in
      (key, occ :: existing) :: List.remove_assoc key acc)
    [] occurrences

(* Print CLI header *)
let print_cli_header () =
  Fmt.pr "@[<v>Symbol Occurrence Report@,";
  Fmt.pr "========================@,@,"

(* Print CLI summary statistics *)
let print_cli_summary occurrences =
  let total_symbols = List.length occurrences in
  let used_symbols = List.filter (fun o -> o.usage_class = Used) occurrences in
  let unused_symbols =
    List.filter (fun o -> o.usage_class = Unused) occurrences
  in
  let excluded_only =
    List.filter (fun o -> o.usage_class = Used_only_in_excluded) occurrences
  in

  Fmt.pr "Total symbols: %d@," total_symbols;
  Fmt.pr "Used symbols: %d@," (List.length used_symbols);
  Fmt.pr "Unused symbols: %d@," (List.length unused_symbols);
  Fmt.pr "Used only in excluded dirs: %d@,@," (List.length excluded_only)

(* Print usage locations for an occurrence *)
let print_usage_locations occ =
  if occ.occurrences > 0 then
    (* Filter out the definition location itself *)
    let usage_locations =
      List.filter
        (fun loc ->
          (* Filter out locations on the same line as the definition *)
          loc.file <> occ.symbol.location.file
          || loc.start_line <> occ.symbol.location.start_line)
        occ.locations
    in
    if usage_locations <> [] then (
      Fmt.pr "    Used in:@,";
      List.iter
        (fun loc -> Fmt.pr "      %a@," pp_location_link loc)
        usage_locations)

(* Print occurrences for a single file *)
let print_file_occurrences file occs =
  Fmt.pr "@[<v2>File: %s@," file;
  let sorted_occs =
    List.sort
      (fun o1 o2 ->
        match String.compare o1.symbol.name o2.symbol.name with
        | 0 -> compare o1.symbol.kind o2.symbol.kind
        | n -> n)
      occs
  in
  List.iter
    (fun occ ->
      Fmt.pr "  %a - %a@,"
        (fun fmt () -> pp_symbol_with_count fmt occ.symbol occ.occurrences)
        () pp_usage_classification occ.usage_class;
      print_usage_locations occ)
    sorted_occs;
  Fmt.pr "@]@,"

let render_cli occurrences =
  let by_file = group_by_file occurrences in
  let sorted_files =
    List.sort (fun (f1, _) (f2, _) -> String.compare f1 f2) by_file
  in

  print_cli_header ();
  print_cli_summary occurrences;

  (* By file *)
  List.iter (fun (file, occs) -> print_file_occurrences file occs) sorted_files;
  Fmt.pr "@]@."

let escape_html s =
  let buffer = Buffer.create (String.length s) in
  String.iter
    (function
      | '<' -> Buffer.add_string buffer "&lt;"
      | '>' -> Buffer.add_string buffer "&gt;"
      | '&' -> Buffer.add_string buffer "&amp;"
      | '"' -> Buffer.add_string buffer "&quot;"
      | '\'' -> Buffer.add_string buffer "&#39;"
      | c -> Buffer.add_char buffer c)
    s;
  Buffer.contents buffer

(* Write HTML header and CSS *)
let write_html_header fmt =
  Fmt.pf fmt "<!DOCTYPE html>@.";
  Fmt.pf fmt "<html>@.";
  Fmt.pf fmt "<head>@.";
  Fmt.pf fmt "  <meta charset=\"UTF-8\">@.";
  Fmt.pf fmt "  <title>Prune Symbol Report</title>@.";
  Fmt.pf fmt "  <style>@.";
  Fmt.pf fmt
    "    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', \
     Roboto, sans-serif; margin: 20px; }@.";
  Fmt.pf fmt "    h1, h2, h3 { color: #333; }@.";
  Fmt.pf fmt
    "    .summary { background: #f5f5f5; padding: 15px; border-radius: 5px; \
     margin-bottom: 20px; }@.";
  Fmt.pf fmt
    "    .file-section { margin-bottom: 30px; border: 1px solid #ddd; padding: \
     15px; border-radius: 5px; }@.";
  Fmt.pf fmt
    "    .symbol { margin: 10px 0; padding: 10px; background: #fafafa; \
     border-radius: 3px; }@.";
  Fmt.pf fmt "    .unused { background: #ffe6e6; }@.";
  Fmt.pf fmt "    .used { background: #e6ffe6; }@.";
  Fmt.pf fmt "    .excluded-only { background: #fff3cd; }@.";
  Fmt.pf fmt
    "    .location { font-family: monospace; font-size: 0.9em; color: #666; \
     margin-left: 20px; }@.";
  Fmt.pf fmt "    .kind { font-weight: bold; color: #0066cc; }@.";
  Fmt.pf fmt "    .name { font-family: monospace; font-weight: bold; }@.";
  Fmt.pf fmt "    .count { color: #666; font-size: 0.9em; }@.";
  Fmt.pf fmt "    a { color: #0066cc; text-decoration: none; }@.";
  Fmt.pf fmt "    a:hover { text-decoration: underline; }@.";
  Fmt.pf fmt "    .tab-buttons { margin-bottom: 20px; }@.";
  Fmt.pf fmt
    "    .tab-button { padding: 10px 20px; margin-right: 5px; border: 1px \
     solid #ddd; background: #f5f5f5; cursor: pointer; }@.";
  Fmt.pf fmt "    .tab-button.active { background: #0066cc; color: white; }@.";
  Fmt.pf fmt "    .tab-content { display: none; }@.";
  Fmt.pf fmt "    .tab-content.active { display: block; }@.";
  Fmt.pf fmt "  </style>@.";
  Fmt.pf fmt "</head>@."

(* Write summary section *)
let write_summary fmt occurrences =
  let total_symbols = List.length occurrences in
  let used_symbols = List.filter (fun o -> o.usage_class = Used) occurrences in
  let unused_symbols =
    List.filter (fun o -> o.usage_class = Unused) occurrences
  in
  let excluded_only =
    List.filter (fun o -> o.usage_class = Used_only_in_excluded) occurrences
  in

  Fmt.pf fmt "<div class=\"summary\">@.";
  Fmt.pf fmt "  <h2>Summary</h2>@.";
  Fmt.pf fmt "  <p>Total symbols: %d</p>@." total_symbols;
  Fmt.pf fmt "  <p>Used symbols: %d</p>@." (List.length used_symbols);
  Fmt.pf fmt "  <p>Unused symbols: %d</p>@." (List.length unused_symbols);
  Fmt.pf fmt "  <p>Used only in excluded directories: %d</p>@."
    (List.length excluded_only);
  Fmt.pf fmt "</div>@."

(* Write tab buttons *)
let write_tab_buttons fmt =
  Fmt.pf fmt "<div class=\"tab-buttons\">@.";
  Fmt.pf fmt
    "  <button class=\"tab-button active\" onclick=\"showTab('by-file')\">By \
     File</button>@.";
  Fmt.pf fmt
    "  <button class=\"tab-button\" onclick=\"showTab('by-symbol')\">By \
     Symbol</button>@.";
  Fmt.pf fmt "</div>@."

(* Get CSS class name for usage classification *)
let class_of_usage = function
  | Unused -> "unused"
  | Used -> "used"
  | Used_only_in_excluded -> "excluded-only"
  | Unknown -> "unknown"

(* Filter usage locations excluding definition *)
let filter_usage_locations occ =
  List.filter
    (fun loc ->
      loc.file <> occ.symbol.location.file
      || loc.start_line <> occ.symbol.location.start_line)
    occ.locations

(* Write symbol occurrence *)
let write_symbol fmt occ =
  let class_name = class_of_usage occ.usage_class in
  Fmt.pf fmt "    <div class=\"symbol %s\">@." class_name;
  Fmt.pf fmt "      <span class=\"kind\">%s</span> "
    (escape_html (string_of_symbol_kind occ.symbol.kind));
  Fmt.pf fmt "      <span class=\"name\">%s</span> "
    (escape_html occ.symbol.name);
  Fmt.pf fmt "      <span class=\"count\">(%d occurrences)</span>@."
    occ.occurrences;
  if occ.occurrences > 0 then (
    let usage_locations = filter_usage_locations occ in
    if usage_locations <> [] then (
      Fmt.pf fmt "      <div>Used in:</div>@.";
      List.iter
        (fun loc ->
          Fmt.pf fmt "      <div class=\"location\">%s:%d:%d</div>@."
            (escape_html loc.file) loc.start_line loc.start_col)
        usage_locations);
    Fmt.pf fmt "    </div>@.")

(* Write By File view *)
let write_by_file_view fmt by_file =
  Fmt.pf fmt "<div id=\"by-file\" class=\"tab-content active\">@.";
  Fmt.pf fmt "  <h2>Symbols by File</h2>@.";
  List.iter
    (fun (file, occs) ->
      Fmt.pf fmt "  <div class=\"file-section\">@.";
      Fmt.pf fmt "    <h3>%s</h3>@." (escape_html file);
      List.iter (write_symbol fmt) occs;
      Fmt.pf fmt "  </div>@.")
    (List.sort (fun (f1, _) (f2, _) -> String.compare f1 f2) by_file);
  Fmt.pf fmt "</div>@."

(* Write By Symbol view *)
let write_by_symbol_view fmt by_symbol =
  Fmt.pf fmt "<div id=\"by-symbol\" class=\"tab-content\">@.";
  Fmt.pf fmt "  <h2>All Symbols</h2>@.";
  List.iter
    (fun ((name, kind), occs) ->
      let first_occ = List.hd occs in
      let total_occurrences =
        List.fold_left (fun acc o -> acc + o.occurrences) 0 occs
      in
      let class_name = class_of_usage first_occ.usage_class in

      Fmt.pf fmt "  <div class=\"symbol %s\">@." class_name;
      Fmt.pf fmt "    <span class=\"kind\">%s</span> "
        (escape_html (string_of_symbol_kind kind));
      Fmt.pf fmt "    <span class=\"name\">%s</span> " (escape_html name);
      Fmt.pf fmt "    <span class=\"count\">(%d total occurrences)</span>@."
        total_occurrences;

      (* Show where it's defined *)
      Fmt.pf fmt "    <div>Defined in:</div>@.";
      List.iter
        (fun occ ->
          Fmt.pf fmt "    <div class=\"location\">%s:%d:%d</div>@."
            (escape_html occ.symbol.location.file)
            occ.symbol.location.start_line occ.symbol.location.start_col)
        occs;

      (* Show all usage locations *)
      let usage_locations =
        List.concat_map (fun occ -> filter_usage_locations occ) occs
      in
      if usage_locations <> [] then (
        Fmt.pf fmt "    <div>Used in:</div>@.";
        List.iter
          (fun loc ->
            Fmt.pf fmt "    <div class=\"location\">%s:%d:%d</div>@."
              (escape_html loc.file) loc.start_line loc.start_col)
          usage_locations);
      Fmt.pf fmt "  </div>@.")
    (List.sort
       (fun ((n1, k1), _) ((n2, k2), _) ->
         match String.compare n1 n2 with 0 -> compare k1 k2 | n -> n)
       by_symbol);
  Fmt.pf fmt "</div>@."

(* Write JavaScript for tab switching *)
let write_javascript fmt =
  Fmt.pf fmt "<script>@.";
  Fmt.pf fmt "function showTab(tabName) {@.";
  Fmt.pf fmt "  var tabs = document.getElementsByClassName('tab-content');@.";
  Fmt.pf fmt "  for (var i = 0; i < tabs.length; i++) {@.";
  Fmt.pf fmt "    tabs[i].classList.remove('active');@.";
  Fmt.pf fmt "  }@.";
  Fmt.pf fmt "  var buttons = document.getElementsByClassName('tab-button');@.";
  Fmt.pf fmt "  for (var i = 0; i < buttons.length; i++) {@.";
  Fmt.pf fmt "    buttons[i].classList.remove('active');@.";
  Fmt.pf fmt "  }@.";
  Fmt.pf fmt "  document.getElementById(tabName).classList.add('active');@.";
  Fmt.pf fmt "  event.target.classList.add('active');@.";
  Fmt.pf fmt "}@.";
  Fmt.pf fmt "</script>@."

let render_html output_dir occurrences =
  let html_file = Filename.concat output_dir "index.html" in
  let oc = open_out html_file in
  let fmt = Format.formatter_of_out_channel oc in

  let by_file = group_by_file occurrences in
  let by_symbol = group_by_symbol occurrences in

  (* HTML header *)
  write_html_header fmt;
  Fmt.pf fmt "<body>@.";

  Fmt.pf fmt "<h1>Prune Symbol Occurrence Report</h1>@.";

  (* Summary *)
  write_summary fmt occurrences;

  (* Tabs *)
  write_tab_buttons fmt;

  (* By File View *)
  write_by_file_view fmt by_file;

  (* By Symbol View *)
  write_by_symbol_view fmt by_symbol;

  (* JavaScript *)
  write_javascript fmt;

  Fmt.pf fmt "</body>@.";
  Fmt.pf fmt "</html>@.";
  Format.pp_print_flush fmt ();
  close_out oc;

  Fmt.pr "HTML report generated: %s@." html_file

let run ~format ~output_dir ~root_dir ~mli_files =
  (* Create cache *)
  let cache = Cache.create () in

  if mli_files = [] then Error (`Msg "No .mli files found to analyze")
  else
    (* Use Analysis module to get all symbol occurrences *)
    match Analysis.get_all_symbol_occurrences ~cache root_dir mli_files with
    | Error (`Build_error _) ->
        Error (`Msg "Build failed - please fix build errors first")
    | Error (`Msg msg) -> Error (`Msg msg)
    | Ok all_occurrences -> (
        (* Render based on format *)
        match format with
        | Cli -> Ok (render_cli all_occurrences)
        | Html -> (
            match output_dir with
            | None -> Error (`Msg "Output directory required for HTML format")
            | Some dir ->
                (* Create output directory if needed *)
                (try Unix.mkdir dir 0o755
                 with Unix.Unix_error (Unix.EEXIST, _, _) -> ());
                Ok (render_html dir all_occurrences)))
