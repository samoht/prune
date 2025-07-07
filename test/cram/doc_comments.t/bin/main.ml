(* Use some functions to prevent them from being marked as unused *)
let () =
  Doclib.used ();
  let _ = Doclib.used_with_docs 42 in
  ()