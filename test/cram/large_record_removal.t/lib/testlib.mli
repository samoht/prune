(** This is a used function *)
val used_function : int -> int

(** This is an unused large record type that spans many lines *)
type unused_large_record = {
  field1 : string;
  field2 : int;
  field3 : float;
  field4 : bool;
  field5 : string list;
  field6 : int option;
  field7 : (string * int) list;
  field8 : unit -> unit;
  field9 : string array;
  field10 : bytes;
  field11 : char;
  field12 : int32;
  field13 : int64;
  field14 : nativeint;
  field15 : string * string * string;
  field16 : [ `A | `B | `C ];
  field17 : int ref;
  field18 : (int -> int) list;
  field19 : string lazy_t;
  field20 : unit Lazy.t;
}

(** Another unused type *)
type unused_simple = int

(** This is a used type *)
type used_type = string