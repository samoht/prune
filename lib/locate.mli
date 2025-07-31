(** AST-based location finding using ppxlib *)

val enclosing_record :
  cache:Cache.t ->
  file:string ->
  line:int ->
  col:int ->
  (Types.location, [ `Msg of string ]) result
(** [enclosing_record ~cache ~file ~line ~col] gets the bounds of the enclosing
    record construction. Used for empty record detection after field removal. *)

val value_binding :
  cache:Cache.t ->
  file:string ->
  line:int ->
  col:int ->
  (Types.location, [ `Msg of string ]) result
(** [value_binding ~cache ~file ~line ~col] gets the bounds of a value binding
    for removal. This specifically looks for value bindings at any nesting level
    (including inside modules) and returns just the binding bounds, not the
    entire enclosing structure. *)

val item_with_docs :
  cache:Cache.t ->
  file:string ->
  line:int ->
  col:int ->
  (Types.location, [ `Msg of string ]) result
(** [item_with_docs ~cache ~file ~line ~col] gets the bounds of a structure item
    including its documentation comments. This finds the structure item at the
    given position and returns its full bounds including any preceding doc
    comments. *)

type field_info = {
  field_name : string;  (** The field name *)
  full_field_bounds : Types.location;
      (** Full bounds including field name, =, value, and semicolon if present
      *)
  enclosing_record : Types.location;
      (** Location of the enclosing record \{\} *)
  total_fields : int;  (** Total number of fields in the record *)
  context : [ `Type_definition | `Record_construction ];
      (** Whether this is in a type definition or a record construction *)
}
(** Information about a field in a record *)

val field_info :
  cache:Cache.t ->
  file:string ->
  line:int ->
  col:int ->
  field_name:string ->
  (field_info, [ `Msg of string ]) result
(** [field_info ~cache ~file ~line ~col ~field_name] gets comprehensive
    information about a field at the given position. This includes all the
    context needed for proper field removal. *)

type type_def_info = {
  type_name : string;
  type_keyword_loc : Types.location;  (** Location of 'type' keyword *)
  equals_loc : Types.location option;  (** Location of '=' if present *)
  kind : [ `Abstract | `Record | `Variant | `Alias ];
  full_bounds : Types.location;
}
(** Information about a type definition *)

val type_definition_info :
  cache:Cache.t ->
  file:string ->
  line:int ->
  col:int ->
  (type_def_info, [ `Msg of string ]) result
(** [type_definition_info ~cache ~file ~line ~col] gets information about a type
    definition at the given position. This includes the location of the equals
    sign which is needed for replacing record types with unit. *)
