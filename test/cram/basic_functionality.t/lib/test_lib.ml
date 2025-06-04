let used_value x = x * 2

let unused_value s = s ^ "_unused"

type used_type = int

type unused_type = float

exception Used_error

exception Unused_error

module Used_module = String

module Unused_module = List