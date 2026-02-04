let used_function x = string_of_int x
let unused_function f = f > 0.0
type used_type = string * int
type unused_type = bool list
type cross_ref_type = bool
let cross_module_function x = Other_module.helper_function x
let completely_unused () = ()