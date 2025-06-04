(* Tests for field removal functionality *)
open Alcotest
open Prune

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
  let temp_file = create_temp_file content in

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
  let cache = Cache.create () in
  let result =
    Removal.remove_unused_exports ~cache "." temp_file
      [ { name = "address"; kind = Field; location = warning.location } ]
  in

  match result with
  | Error e ->
      Sys.remove temp_file;
      fail (Format.asprintf "Field removal failed: %a" Prune.pp_error e)
  | Ok () ->
      let new_content = read_file temp_file in
      Sys.remove temp_file;
      Printf.printf "Content after removal:\n%s\n" new_content;
      (* Check that the field was removed from the type definition *)
      let address_field_re =
        Re.(
          compile
            (seq [ str "address"; rep any; str ":"; rep any; str "string" ]))
      in
      let has_address_field = Re.execp address_field_re new_content in
      check bool "field removed from type (replaced with spaces)" false
        has_address_field;
      (* The field usage in record construction should still be there *)
      let address_usage_re =
        Re.(
          compile
            (seq [ str "address"; rep any; str "="; rep any; str "\"unused\"" ]))
      in
      let has_address_usage = Re.execp address_usage_re new_content in
      check bool "field usage still present" true has_address_usage

let test_field_removal_preserves_other_fields () =
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
  let temp_file = create_temp_file content in

  let warning : Prune.warning_info =
    {
      location = location temp_file ~line:5 ~start_col:2 ~end_line:5 ~end_col:16;
      name = "debug";
      warning_type = Prune.Unused_field;
      location_precision = Prune.Exact_statement;
    }
  in

  let cache = Cache.create () in
  let result =
    Removal.remove_unused_exports ~cache "." temp_file
      [ { name = "debug"; kind = Field; location = warning.location } ]
  in

  match result with
  | Error e ->
      Sys.remove temp_file;
      fail (Format.asprintf "Field removal failed: %a" Prune.pp_error e)
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

let test_field_removal_in_module () =
  (* Tests field removal within a module structure *)
  let content =
    {|module Internal : sig end = struct
  type person = {
    name : string;
    age : int;
    address : string;  (* Warning 69: unused field *)
  }

  let make name age = { name; age; address = "unused" }
  let get_name p = p.name
  let get_age p = p.age
  let _ = make, get_name, get_age
end|}
  in
  let temp_file = create_temp_file content in

  (* Create warning matching what dune would report *)
  let warning : Prune.warning_info =
    {
      location =
        location temp_file ~line:5 ~start_col:4 (* Points to "address" *)
          ~end_line:5 ~end_col:21
        (* Through the whole field definition *);
      name = "address";
      warning_type = Prune.Unused_field;
      location_precision = Prune.Exact_statement;
    }
  in

  let cache = Cache.create () in
  let result =
    Removal.remove_unused_exports ~cache "." temp_file
      [ { name = "address"; kind = Field; location = warning.location } ]
  in

  match result with
  | Error e ->
      Sys.remove temp_file;
      fail (Format.asprintf "Field removal failed: %a" Prune.pp_error e)
  | Ok () ->
      let new_content = read_file temp_file in
      Sys.remove temp_file;
      Printf.printf "Content after removal:\n%s\n" new_content;
      (* Check exact line 5 to see what happened *)
      let lines = String.split_on_char '\n' new_content in
      let line5 = List.nth lines 4 in
      (* 0-indexed *)
      Printf.printf "Line 5 after removal: '%s'\n" line5;
      (* The field definition should be replaced with spaces *)
      let address_re = Re.(compile (str "address")) in
      check bool "address field text removed" false (Re.execp address_re line5)

let tests =
  ( "Field removal",
    [
      test_case "unused field removal" `Quick test_unused_field_removal;
      test_case "field removal preserves other fields" `Quick
        test_field_removal_preserves_other_fields;
      test_case "field removal in module" `Quick test_field_removal_in_module;
    ] )
