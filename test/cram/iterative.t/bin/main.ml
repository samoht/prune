open Testlib

let () =
  (* Using the entry point of a chain *)
  let result = entry 10 in
  Printf.printf "Result: %d\n" result