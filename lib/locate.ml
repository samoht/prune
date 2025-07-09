(* AST-based location finding using ppxlib *)

module T = Types
open Ppxlib
module Log = (val Logs.src_log (Logs.Src.create "prune.locate") : Logs.LOG)

(* Type definitions *)

type field_info = {
  field_name : string;
  full_field_bounds : T.location; (* Full bounds including everything *)
  enclosing_record : T.location; (* Location of the enclosing record {} *)
  total_fields : int; (* Total number of fields in the record *)
  context : [ `Type_definition | `Record_construction ];
}

type type_def_info = {
  type_name : string;
  type_keyword_loc : T.location;
  equals_loc : T.location option;
  kind : [ `Abstract | `Record | `Variant | `Alias ];
  full_bounds : T.location;
}

(* Exceptions for early termination in visitors *)
exception Found_field of field_info
exception Found_type_def of type_def_info
exception Found_location of T.location

(* Error helper functions *)
let err fmt = Fmt.kstr (fun e -> Error (`Msg e)) fmt
let err_expected_impl file = err "Expected implementation file: %s" file
let err_expected_intf file = err "Expected interface file: %s" file
let err_field_not_found = err "Field not found at position"
let err_no_type_def = err "No type definition found at position"
let err_no_sig_item = err "No signature item found at position"
let err_no_struct_item = err "No structure item found at position"
let err_no_value_binding = err "No value binding found at position"
let err_no_enclosing_record = err "Could not find enclosing record"

(* Basic utilities *)

let rec get_longident_last = function
  | Longident.Lident s -> s
  | Longident.Ldot (_, s) -> s
  | Longident.Lapply (_, l) -> get_longident_last l

let location_of_ppxlib_location file (loc : Location.t) : T.location =
  T.location file ~line:loc.loc_start.pos_lnum
    ~start_col:(loc.loc_start.pos_cnum - loc.loc_start.pos_bol)
    ~end_line:loc.loc_end.pos_lnum
    ~end_col:(loc.loc_end.pos_cnum - loc.loc_end.pos_bol)

(* AST cache access *)

let get_ast ~cache file =
  match Cache.get_ast cache file with
  | Ok (Implementation ast) -> Ok ast
  | Ok (Interface _) -> err_expected_impl file
  | Error e -> Error e

let get_interface_ast ~cache file =
  match Cache.get_ast cache file with
  | Ok (Interface ast) -> Ok ast
  | Ok (Implementation _) -> err_expected_intf file
  | Error e -> Error e

(* Generic AST traversal helpers *)

let location_contains loc ~line ~col =
  loc.T.start_line <= line && loc.T.end_line >= line
  && (loc.T.start_line < line || loc.T.start_col <= col)
  && (loc.T.end_line > line || loc.T.end_col >= col)

let to_full_lines loc =
  T.location loc.T.file ~line:loc.T.start_line ~end_line:loc.T.end_line
    ~start_col:0 ~end_col:max_int

(* Field handling *)

let extend_field_bounds field_loc next_item_loc is_last_field =
  if is_last_field then
    (* For last field, extend to one character before the record end *)
    T.extend field_loc ~end_line:next_item_loc.T.end_line
      ~end_col:(next_item_loc.T.end_col - 1)
  else
    (* For other fields, extend to the start of the next field *)
    T.extend field_loc ~end_line:next_item_loc.T.start_line
      ~end_col:next_item_loc.T.start_col

let find_field_in_type file type_decl ~line ~col ~field_name =
  match type_decl.ptype_kind with
  | Ptype_record label_decls ->
      let record_loc = location_of_ppxlib_location file type_decl.ptype_loc in
      let total_fields = List.length label_decls in
      let decls_array = Array.of_list label_decls in

      Array.find_mapi
        (fun i ld ->
          let name_loc = location_of_ppxlib_location file ld.pld_name.loc in
          if
            ld.pld_name.txt = field_name
            && location_contains name_loc ~line ~col
          then
            let full_loc = location_of_ppxlib_location file ld.pld_loc in
            let next_loc =
              if i = total_fields - 1 then record_loc
              else location_of_ppxlib_location file decls_array.(i + 1).pld_loc
            in
            let extended =
              extend_field_bounds full_loc next_loc (i = total_fields - 1)
            in
            Some
              {
                field_name = ld.pld_name.txt;
                full_field_bounds = extended;
                enclosing_record = record_loc;
                total_fields;
                context = `Type_definition;
              }
          else None)
        decls_array
  | _ -> None

let find_field_in_record file expr ~line ~col ~field_name =
  match expr.pexp_desc with
  | Pexp_record (fields, _) ->
      let record_loc = location_of_ppxlib_location file expr.pexp_loc in
      let total_fields = List.length fields in
      let fields_array = Array.of_list fields in

      Array.find_mapi
        (fun i ((lid : Longident.t Asttypes.loc), expr) ->
          let field_loc = location_of_ppxlib_location file lid.loc in
          let name = get_longident_last lid.txt in
          if name = field_name && location_contains field_loc ~line ~col then
            let value_loc = location_of_ppxlib_location file expr.pexp_loc in
            let full_loc = T.merge field_loc value_loc in
            let next_loc =
              if i = total_fields - 1 then record_loc
              else
                let next_lid, _ = fields_array.(i + 1) in
                location_of_ppxlib_location file next_lid.loc
            in
            let extended =
              extend_field_bounds full_loc next_loc (i = total_fields - 1)
            in
            Some
              {
                field_name = name;
                full_field_bounds = extended;
                enclosing_record = record_loc;
                total_fields;
                context = `Record_construction;
              }
          else None)
        fields_array
  | _ -> None

(* Type definition handling *)

(* Get type keyword location *)
let get_type_keyword_loc file item =
  let item_loc = location_of_ppxlib_location file item.pstr_loc in
  T.extend item_loc ~end_line:item_loc.start_line
    ~end_col:(item_loc.start_col + 4)
(* "type" *)

(* Get equals location for type definition *)
let get_equals_loc file td =
  match (td.ptype_kind, td.ptype_manifest) with
  | Ptype_abstract, Some _ | Ptype_record _, _ | Ptype_variant _, _ ->
      let name_loc = location_of_ppxlib_location file td.ptype_name.loc in
      Some
        (T.location file ~line:name_loc.end_line
           ~start_col:(name_loc.end_col + 1) ~end_line:name_loc.end_line
           ~end_col:(name_loc.end_col + 2))
  | _ -> None

(* Get type definition kind *)
let get_type_kind td =
  match td.ptype_kind with
  | Ptype_abstract -> if td.ptype_manifest <> None then `Alias else `Abstract
  | Ptype_record _ -> `Record
  | Ptype_variant _ -> `Variant
  | Ptype_open -> `Abstract

(* Process type declaration and create type_def_info *)
let process_type_decl file item td loc =
  let type_keyword_loc = get_type_keyword_loc file item in
  let equals_loc = get_equals_loc file td in
  let kind = get_type_kind td in
  {
    type_name = td.ptype_name.txt;
    type_keyword_loc;
    equals_loc;
    kind;
    full_bounds = loc;
  }

let find_type_definition file ast ~line ~col =
  let visitor =
    object
      inherit Ast_traverse.iter as super

      method! structure_item item =
        match item.pstr_desc with
        | Pstr_type (_, type_decls) ->
            List.iter
              (fun td ->
                let loc = location_of_ppxlib_location file td.ptype_loc in
                if location_contains loc ~line ~col then
                  let type_def_info = process_type_decl file item td loc in
                  raise (Found_type_def type_def_info))
              type_decls;
            super#structure_item item
        | _ -> super#structure_item item
    end
  in

  try
    visitor#structure ast;
    None
  with Found_type_def info -> Some info

(* Structure/signature item bounds *)

let get_structure_item_bounds file ast ~line ~col =
  let items = Array.of_list ast in
  Array.find_mapi
    (fun _idx item ->
      let loc = location_of_ppxlib_location file item.pstr_loc in
      if location_contains loc ~line ~col then
        (* Return just the item bounds - comments will be added by
           extend_location_with_comments *)
        Some (to_full_lines loc)
      else None)
    items

let rec find_value_in_module file module_type ~line ~col =
  match module_type.pmty_desc with
  | Pmty_signature items ->
      (* Look for value declarations inside this module signature *)
      let items_array = Array.of_list items in
      Array.find_mapi
        (fun _idx item ->
          match item.psig_desc with
          | Psig_value vd ->
              let loc = location_of_ppxlib_location file vd.pval_loc in
              if location_contains loc ~line ~col then
                (* Found the value declaration *)
                Some (to_full_lines loc)
              else None
          | Psig_module md ->
              (* Recursively check inside nested modules *)
              find_value_in_module file md.pmd_type ~line ~col
          | _ -> None)
        items_array
  | _ -> None

let get_signature_item_bounds file ast ~line ~col =
  Log.debug (fun m ->
      m "get_signature_item_bounds: looking for item at %s:%d:%d" file line col);
  let items = Array.of_list ast in
  Array.find_mapi
    (fun _idx item ->
      let loc = location_of_ppxlib_location file item.psig_loc in
      Log.debug (fun m ->
          m "  Checking item at %d:%d-%d:%d" loc.start_line loc.start_col
            loc.end_line loc.end_col);
      if location_contains loc ~line ~col then (
        Log.debug (fun m -> m "  Found matching item!");
        match item.psig_desc with
        | Psig_value _ ->
            (* For values, return just the value declaration bounds *)
            Some (to_full_lines loc)
        | Psig_module md -> (
            (* Check if we're inside a module - if so, find the specific
               value *)
            match find_value_in_module file md.pmd_type ~line ~col with
            | Some bounds -> Some bounds
            | None ->
                (* Not inside a value, return the whole module *)
                Some (to_full_lines loc))
        | _ ->
            (* For other items (types, exceptions, etc.), return normal
               bounds *)
            Some (to_full_lines loc))
      else None)
    items

(* Public API *)

let get_field_info ~cache ~file ~line ~col ~field_name =
  match get_ast ~cache file with
  | Error e -> Error e
  | Ok ast -> (
      let visitor =
        object
          inherit Ast_traverse.iter as super

          method! type_declaration td =
            match find_field_in_type file td ~line ~col ~field_name with
            | Some info -> raise (Found_field info)
            | None -> super#type_declaration td

          method! expression e =
            match find_field_in_record file e ~line ~col ~field_name with
            | Some info -> raise (Found_field info)
            | None -> super#expression e
        end
      in

      try
        visitor#structure ast;
        err_field_not_found
      with Found_field info -> Ok info)

let get_type_definition_info ~cache ~file ~line ~col =
  match get_ast ~cache file with
  | Error e -> Error e
  | Ok ast -> (
      match find_type_definition file ast ~line ~col with
      | None -> err_no_type_def
      | Some info -> Ok info)

let get_item_with_docs ~cache ~file ~line ~col =
  if Filename.check_suffix file ".mli" then
    match get_interface_ast ~cache file with
    | Error e -> Error e
    | Ok ast -> (
        match get_signature_item_bounds file ast ~line ~col with
        | None -> err_no_sig_item
        | Some bounds ->
            (* Extend with doc comments if needed *)
            Ok (Comments.extend_location_with_comments cache file bounds))
  else
    match get_ast ~cache file with
    | Error e -> Error e
    | Ok ast -> (
        match get_structure_item_bounds file ast ~line ~col with
        | None -> err_no_struct_item
        | Some bounds ->
            Ok (Comments.extend_location_with_comments cache file bounds))

let find_value_binding ~cache ~file ~line ~col =
  match get_ast ~cache file with
  | Error e -> Error e
  | Ok ast -> (
      let visitor =
        object
          inherit Ast_traverse.iter as super

          method! value_binding vb =
            let loc = location_of_ppxlib_location file vb.pvb_loc in
            if location_contains loc ~line ~col then raise (Found_location loc)
            else super#value_binding vb
        end
      in
      try
        visitor#structure ast;
        err_no_value_binding
      with Found_location loc ->
        Ok (Comments.extend_location_with_comments cache file loc))

let get_enclosing_record ~cache ~file ~line ~col =
  match get_ast ~cache file with
  | Error e -> Error e
  | Ok ast -> (
      let innermost = ref None in
      let visitor =
        object
          inherit Ast_traverse.iter as super

          method! expression e =
            match e.pexp_desc with
            | Pexp_record (_, _) ->
                let loc = location_of_ppxlib_location file e.pexp_loc in
                (if location_contains loc ~line ~col then
                   (* Update innermost if this record is smaller/more
                      specific *)
                   match !innermost with
                   | None -> innermost := Some loc
                   | Some prev_loc ->
                       (* If this location is contained within the previous one,
                          it's more specific *)
                       if
                         loc.T.start_line > prev_loc.T.start_line
                         || loc.T.start_line = prev_loc.T.start_line
                            && loc.T.start_col >= prev_loc.T.start_col
                         || loc.T.end_line < prev_loc.T.end_line
                         || loc.T.end_line = prev_loc.T.end_line
                            && loc.T.end_col <= prev_loc.T.end_col
                       then innermost := Some loc);
                super#expression e
            | _ -> super#expression e
        end
      in

      visitor#structure ast;
      match !innermost with
      | None -> err_no_enclosing_record
      | Some loc -> Ok loc)
