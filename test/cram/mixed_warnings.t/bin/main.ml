let () =
  let c = Config.make_connection ~host:"example.com" ~port:443 in
  Printf.printf "Connection: %s\n" (Config.format_connection c);
  Printf.printf "Level: %s\n" (Config.log_level_to_string Config.default_log_level);
  Printf.printf "Default host: %s\n" Config.default_connection.host;
  Printf.printf "Default port: %d\n" Config.default_connection.port;
  (* Only uses Info, Warning, Error constructors *)
  List.iter
    (fun l -> Printf.printf "  %s\n" (Config.log_level_to_string l))
    [ Config.Info; Config.Warning; Config.Error ]
