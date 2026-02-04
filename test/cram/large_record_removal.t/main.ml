let () = 
  let x = Testlib.used_function 42 in
  let _: Testlib.used_type = "hello" in
  Printf.printf "Result: %d\n" x