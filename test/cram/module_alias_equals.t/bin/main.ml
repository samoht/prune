open Testlib

let () =
  (* Use A.used_func through the alias *)
  print_endline (Aliases.A.used_func "test");
  (* Use B.another_func through the alias *)
  print_endline (Aliases.B.another_func ())