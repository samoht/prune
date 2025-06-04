let () =
  let person = Testlib.make_person "Alice" in
  Printf.printf "Name: %s\n" (Testlib.get_name person)