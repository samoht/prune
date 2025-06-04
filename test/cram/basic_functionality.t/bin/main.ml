open Test_lib

let () =
  (* Use some exports but not others *)
  let result : used_type = used_value 21 in
  Printf.printf "Result: %d\n" result;
  
  (* Use the exception *)
  (try raise Used_error with
  | Used_error -> Printf.printf "Caught Used_error\n"
  | _ -> ());
  
  (* Use the module alias *)
  let len = Used_module.length "hello" in
  Printf.printf "Length: %d\n" len
