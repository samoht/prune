let () =
  let result = Lib1.Module1.used_function 42 in
  let len = Lib2.Module2.another_used "test" in
  Printf.printf "Result: %s, Len: %d\n" result len