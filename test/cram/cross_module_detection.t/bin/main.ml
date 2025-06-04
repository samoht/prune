open Testlib

let () =
  (* Use the function *)
  let result = used_function 42 in
  
  (* Use the type in annotation *)
  let data : used_type = ("hello", 5) in
  
  (* Use the cross reference type *)
  let flag : cross_ref_type = true in
  let flag_result = if flag then 42 else 0 in
  
  (* Use cross-module function that calls Other_module.helper_function *)
  let cross_result = cross_module_function 10 in
  
  Printf.printf "Result: %s, Data: %s, Flag: %d, Cross: %d\n" result (fst data) flag_result cross_result