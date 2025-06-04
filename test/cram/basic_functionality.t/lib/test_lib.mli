(** A value that is used by main.ml *)
val used_value : int -> int

(** A value that is never used *)
val unused_value : string -> string

(** A type that is used *)
type used_type = int

(** A type that is never used *)
type unused_type = float

(** An exception that is used *)
exception Used_error

(** An exception that is never used *)
exception Unused_error

(** A module alias that is used *)
module Used_module = String

(** A module alias that is never used *)
module Unused_module = List