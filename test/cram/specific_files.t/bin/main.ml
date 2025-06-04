let () =
  let result = Testlib.First.used_function 42 in
  let data : Testlib.First.used_type = ("hello", 5) in
  let len = Testlib.Second.another_used "test" in
  let another_data : Testlib.Second.another_used_type = 10 in
  Printf.printf "Result: %s, Data: %s, Len: %d, Another: %d\n" 
    result (fst data) len another_data