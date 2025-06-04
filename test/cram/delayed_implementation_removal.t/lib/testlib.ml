(* This helper is only used by exported_func, so should be removed when exported_func is removed *)
let unused_helper () = 
  print_endline "helper"

let exported_func () =
  unused_helper ()

let used_func () =
  print_endline "used"