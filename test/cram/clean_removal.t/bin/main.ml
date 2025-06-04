let () =
  let result = Cleanlib.used_function 42 in
  Printf.printf "Result: %d\n" result