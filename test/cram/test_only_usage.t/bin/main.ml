open Mylib

let () =
  (* Use functions in production code *)
  let result = main_function "world" in
  print_endline result;
  
  let n = production_helper 21 in
  Printf.printf "Answer: %d\n" n;
  
  let data = ["a"; "b"; "c"] in
  let processed = process_data data in
  print_endline processed;
  
  let x = utility 3.14 in
  Printf.printf "Double: %f\n" x;
  
  if another_function false then
    print_endline "Success"