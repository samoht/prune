(* Tests for module alias detection *)

(* Test the module name pattern *)
let test_module_name_pattern () =
  let module_name_re = Re.compile Prune.Module_alias.module_name in

  let test_cases =
    [
      ("MyModule", true);
      ("M", true);
      ("Module_123", true);
      ("_Module", true);
      (* Starts with underscore *)
      ("Module'", true);
      (* With apostrophe *)
      ("myModule", false);
      (* Starts with lowercase *)
      ("123Module", false);
      (* Starts with number *)
    ]
  in

  List.iter
    (fun (input, expected) ->
      let matches =
        try
          let m = Re.exec module_name_re input in
          (* Check if the whole string was matched *)
          Re.Group.offset m 0 = (0, String.length input)
        with Not_found -> false
      in
      Alcotest.(check bool)
        (Printf.sprintf "module name: %s" input)
        expected matches)
    test_cases

(* Test whitespace patterns *)
let test_whitespace_patterns () =
  let ws_re = Re.compile Prune.Module_alias.ws in
  let ws1_re = Re.compile Prune.Module_alias.ws1 in

  (* ws should match zero or more spaces *)
  Alcotest.(check bool) "ws matches empty" true (Re.execp ws_re "");
  Alcotest.(check bool) "ws matches space" true (Re.execp ws_re " ");
  Alcotest.(check bool) "ws matches newline" true (Re.execp ws_re "\n");
  Alcotest.(check bool) "ws matches multiple" true (Re.execp ws_re "  \n\r  ");

  (* ws1 should match one or more spaces *)
  Alcotest.(check bool) "ws1 doesn't match empty" false (Re.execp ws1_re "");
  Alcotest.(check bool) "ws1 matches space" true (Re.execp ws1_re " ");
  Alcotest.(check bool) "ws1 matches newline" true (Re.execp ws1_re "\n");
  Alcotest.(check bool) "ws1 matches multiple" true (Re.execp ws1_re "  \n\r  ")

(* Test signature mismatch parsing *)
let test_signature_mismatch_parsing () =
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

  let test_cases =
    [
      ("The value foo is required but not provided", Some "foo");
      ("The value \"bar\" is required but not provided", Some "bar");
      ( "The value \"kpi_comparison\" is required but not provided",
        Some "kpi_comparison" );
      ("Something else", None);
    ]
  in

  List.iter
    (fun (input, expected) ->
      let result =
        try
          let groups = Re.exec value_required_re input in
          Some (Re.Group.get groups 1)
        with Not_found -> None
      in
      Alcotest.(check (option string))
        (Printf.sprintf "signature mismatch: %s" input)
        expected result)
    test_cases

let tests =
  ( "Module alias parsing",
    [
      Alcotest.test_case "Module name pattern" `Quick test_module_name_pattern;
      Alcotest.test_case "Whitespace patterns" `Quick test_whitespace_patterns;
      Alcotest.test_case "Signature mismatch parsing" `Quick
        test_signature_mismatch_parsing;
    ] )
