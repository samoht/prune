(* Use some functions to prevent them from being marked as unused *)
let () =
  Doclib.used ();
  let result = Doclib.used_with_docs 42 in
  Printf.printf "Result: %d\n" result