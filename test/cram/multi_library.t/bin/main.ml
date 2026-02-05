let () =
  let id = Core_types.make_id 42 in
  let name = Core_types.make_name "test" in
  Printf.printf "ID: %d, Name: %s\n" (Core_types.id_to_int id) name;
  Printf.printf "Service: %s\n" (Service.process id)
