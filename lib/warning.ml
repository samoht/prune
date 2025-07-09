(* Warning parsing and handling for prune *)

module Log = (val Logs.src_log (Logs.Src.create "prune.warning") : Logs.LOG)

(* Parse warning 32/34 location from build output line *)
let parse_warning_line line =
  (* Examples: File "lib/prune.ml", line 15, characters 4-17: File
     "lib/brui.mli", lines 5-6, characters 2-80: *)
  let line = String.trim line in
  (* First try single line format *)
  let single_line_re =
    Re.(
      compile
        (seq
           [
             bos;
             str "File \"";
             group (rep1 (compl [ char '"' ]));
             str "\", line ";
             group (rep1 digit);
             str ", characters ";
             group (rep1 digit);
             str "-";
             group (rep1 digit);
             str ":";
           ]))
  in
  (* Also try multi-line format *)
  let multi_line_re =
    Re.(
      compile
        (seq
           [
             bos;
             str "File \"";
             group (rep1 (compl [ char '"' ]));
             str "\", lines ";
             group (rep1 digit);
             str "-";
             group (rep1 digit);
             str ", characters ";
             group (rep1 digit);
             str "-";
             group (rep1 digit);
             str ":";
           ]))
  in
  try
    let groups = Re.exec ~pos:0 single_line_re line in
    let file = Re.Group.get groups 1 in
    let line = int_of_string (Re.Group.get groups 2) in
    let start_col = int_of_string (Re.Group.get groups 3) in
    let end_col = int_of_string (Re.Group.get groups 4) in
    Some (Types.location file ~line ~start_col ~end_col)
  with Not_found -> (
    try
      let groups = Re.exec ~pos:0 multi_line_re line in
      let file = Re.Group.get groups 1 in
      let start_line = int_of_string (Re.Group.get groups 2) in
      let end_line = int_of_string (Re.Group.get groups 3) in
      let start_col = int_of_string (Re.Group.get groups 4) in
      let end_col = int_of_string (Re.Group.get groups 5) in
      Some (Types.location file ~line:start_line ~start_col ~end_line ~end_col)
    with Not_found -> None)

(* Parse warning 32/33/34/69 symbol name and type from warning message *)
(* Helper to create regex for standard unused pattern *)
let unused_pattern prefix =
  (* For warnings that end with a dot, capture everything up to the final dot *)
  Re.(
    seq
      [
        str prefix;
        group (rep1 (alt [ alnum; char '_'; char '.'; char '\'' ]));
        char '.';
      ])

(* Helper to create regex for unused field pattern *)
let unused_field_pattern () =
  Re.(
    alt
      [
        (* Pattern for regular unused fields *)
        seq
          [
            rep (compl [ char ':' ]);
            (* Skip everything before colon *)
            str ":";
            space;
            str "record field ";
            group (rep1 (alt [ alnum; char '_' ]));
            str " is never read";
          ];
        (* Pattern for mutable fields that are never mutated *)
        seq
          [
            rep (compl [ char ':' ]);
            (* Skip everything before colon *)
            str ":";
            space;
            str "mutable record field ";
            group (rep1 (alt [ alnum; char '_' ]));
            str " is never mutated";
          ];
      ])

(* Helper to create regex for warning name extraction *)
let create_name_regex warning_num =
  Re.compile
    (match warning_num with
    | "32" -> unused_pattern ": unused value "
    | "33" -> unused_pattern ": unused open "
    | "34" -> unused_pattern ": unused type "
    | "37" -> unused_pattern ": unused constructor "
    | "38" ->
        Re.(
          seq
            [
              str ": unused exception ";
              group (rep1 (compl [ char '.' ]));
              opt (char '.');
            ])
    | "69" -> unused_field_pattern ()
    | _ -> failwith "Unexpected warning number")

(* Helper to extract module name from qualified name *)
let extract_module_name warning_num raw_name =
  match warning_num with
  | "33" ->
      (* Extract the last component of a qualified module name *)
      let parts = String.split_on_char '.' raw_name in
      List.hd (List.rev parts)
  | _ -> raw_name

(* Helper to get warning type from number *)
let warning_type_of_number = function
  | "32" -> Types.Unused_value
  | "33" -> Types.Unused_open
  | "34" -> Types.Unused_type
  | "37" -> Types.Unused_constructor
  | "38" -> Types.Unused_exception
  | "69" -> Types.Unused_field
  | n -> failwith (Fmt.str "Unexpected warning number: %s" n)

let parse_warning_name_and_type line =
  (* Parse name and type from warning messages *)
  (* First extract the warning number using Re DSL *)
  let num_re =
    Re.(
      compile
        (seq
           [
             alt [ str "Warning"; seq [ str "Error"; space; str "(warning" ] ];
             space;
             group
               (alt
                  [ str "32"; str "33"; str "34"; str "37"; str "38"; str "69" ]);
             (* Match optional space, bracket, or other characters after warning
                number *)
             rep (compl [ char ':' ]);
           ]))
  in

  try
    let num_groups = Re.exec num_re line in
    let warning_num = Re.Group.get num_groups 1 in

    (* Then extract the name based on warning type *)
    let name_re = create_name_regex warning_num in
    let name_groups = Re.exec name_re line in
    (* For warning 69, we need to find which group has the field name *)
    let raw_name =
      if warning_num = "69" then
        (* Try group 1 first (regular field), then group 2 (mutable field) *)
        try Re.Group.get name_groups 1
        with Not_found -> Re.Group.get name_groups 2
      else Re.Group.get name_groups 1
    in

    (* Extract final name and warning type *)
    let name = extract_module_name warning_num raw_name in
    let warning_type =
      if warning_num = "69" then
        (* Check if it's "never mutated" vs "never read" *)
        if Re.execp (Re.compile (Re.str "is never mutated")) line then
          Types.Unnecessary_mutable
        else Types.Unused_field
      else warning_type_of_number warning_num
    in

    Some (name, warning_type)
  with Not_found -> None

(* Create warning info from parsed components *)
let create_warning_info location name warning_type =
  {
    Types.location;
    name;
    warning_type;
    location_precision = Types.precision_of_warning_type warning_type;
  }

(* Parse signature mismatch errors from build output *)
(* Extract signature name from error line *)
let extract_signature_name line =
  let value_required_re =
    Re.(
      compile
        (seq
           [
             str "The value ";
             opt (char '"');
             group (rep1 (compl [ space; char '"' ]));
             opt (char '"');
             str " is required but not provided";
           ]))
  in
  try
    let groups = Re.exec value_required_re line in
    Some (Re.Group.get groups 1)
  with Not_found -> None

(* Find location in the next few lines *)
let find_mli_location lines_to_check =
  let rec search = function
    | [] -> None
    | loc_line :: more -> (
        match parse_warning_line loc_line with
        | Some location when String.ends_with ~suffix:".mli" location.file ->
            Some location
        | _ -> search more)
  in
  search lines_to_check

(* Get next few lines to search for location *)
let get_next_lines rest =
  match rest with l1 :: l2 :: l3 :: _ -> [ l1; l2; l3 ] | lines -> lines

(* Create pairs of (line, remaining_lines) *)
let make_line_pairs lines =
  let rec make_pairs = function
    | [] -> []
    | line :: rest -> (line, rest) :: make_pairs rest
  in
  make_pairs lines

(* Process a single line for signature mismatch *)
let process_signature_line line rest =
  match extract_signature_name line with
  | None -> []
  | Some name -> (
      let next_lines = get_next_lines rest in
      match find_mli_location next_lines with
      | Some location ->
          let warning =
            create_warning_info location name Types.Signature_mismatch
          in
          [ warning ]
      | None -> [])

let parse_signature_mismatch_error lines =
  (* Look for pattern: Error: The implementation "lib/base.ml" does not match
     the interface "lib/base.ml": The value "missing_func" is required but not
     provided File "lib/base.mli", line 2, characters 0-35: Expected
     declaration *)
  let rec find_error = function
    | [] -> []
    | (line, rest) :: remaining_pairs ->
        let warnings = process_signature_line line rest in
        warnings @ find_error remaining_pairs
  in
  find_error (make_line_pairs lines)

(* Parse warnings using a simpler approach - scan for all warning messages
   first, then match with locations *)
let parse_all_from_lines_simple lines =
  let rec find_warnings acc lines_with_idx =
    match lines_with_idx with
    | [] -> List.rev acc
    | (line, idx) :: rest -> (
        (* Look for warning pattern in current line *)
        match parse_warning_name_and_type line with
        | Some (name, warning_type) -> (
            Log.debug (fun m ->
                m "Found warning '%s' type %s on line %d: %s" name
                  (Fmt.str "%a" Types.pp_warning_type warning_type)
                  idx line);
            (* Found a warning, now search backwards for the corresponding
               location *)
            let rec find_location search_idx =
              if search_idx < 0 then None
              else
                let search_line = List.nth lines search_idx in
                match parse_warning_line search_line with
                | Some location -> Some location
                | None ->
                    if search_idx > 0 then find_location (search_idx - 1)
                    else None
            in
            match find_location (idx - 1) with
            | Some location ->
                let warning = create_warning_info location name warning_type in
                find_warnings (warning :: acc) rest
            | None ->
                Log.debug (fun m ->
                    m
                      "Warning %s (type %s) found at line %d but no location \
                       found before it"
                      name
                      (Fmt.str "%a" Types.pp_warning_type warning_type)
                      idx);
                find_warnings acc rest)
        | None -> find_warnings acc rest)
  in
  let indexed_lines = List.mapi (fun i line -> (line, i)) lines in
  find_warnings [] indexed_lines

(* Parse unbound record field errors from build output *)
let parse_unbound_field_error lines =
  (* Look for pattern: Error: Unbound record field address *)
  let unbound_field_re =
    Re.(
      compile
        (seq
           [
             str "Error: Unbound record field";
             rep (alt [ space; char '\t' ]);
             opt (char '"');
             group
               (seq
                  [
                    alt [ alpha; char '_' ];
                    rep (alt [ alnum; char '_'; char '\'' ]);
                  ]);
             opt (char '"');
           ]))
  in
  let rec find_error line_and_idx_pairs acc =
    match line_and_idx_pairs with
    | [] -> acc
    | (line, idx) :: remaining_pairs -> (
        try
          let groups = Re.exec unbound_field_re line in
          let field_name = Re.Group.get groups 1 in

          (* Look backwards for the file location (it comes before the error) *)
          let rec find_location i =
            if i <= 0 then None
            else
              let prev_line = List.nth lines (i - 1) in
              match parse_warning_line prev_line with
              | Some location ->
                  let warning =
                    create_warning_info location field_name Types.Unbound_field
                  in
                  Some warning
              | None -> if i > 1 then find_location (i - 1) else None
          in
          match find_location idx with
          | Some warning -> find_error remaining_pairs (warning :: acc)
          | None -> find_error remaining_pairs acc
        with Not_found -> find_error remaining_pairs acc)
  in
  (* Create pairs of (line, index) for easier processing *)
  let indexed_lines = List.mapi (fun i line -> (line, i)) lines in
  find_error indexed_lines []

(* Parse all warning 32/33/34/69 messages and signature mismatches from build
   output *)
let parse output =
  let lines = String.split_on_char '\n' output in
  (* Parse all types of warnings/errors *)
  let warnings = parse_all_from_lines_simple lines in
  let sig_mismatches = parse_signature_mismatch_error lines in
  let unbound_fields = parse_unbound_field_error lines in

  let all_warnings = warnings @ sig_mismatches @ unbound_fields in

  (* Single summary log if we found anything *)
  if all_warnings <> [] then (
    Log.debug (fun m ->
        m "Parsed %d warnings/errors from %d lines" (List.length all_warnings)
          (List.length lines));
    List.iter
      (fun (w : Types.warning_info) ->
        Log.debug (fun m ->
            m "  %a: %a %s" Types.pp_location w.location Types.pp_warning_type
              w.warning_type w.name))
      all_warnings)
  else
    Log.debug (fun m ->
        m "No warnings found in %d lines of output" (List.length lines));
  all_warnings
