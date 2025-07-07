(* Use some functions to prevent them from being marked as unused *)
let () =
  let _ = Test.used 42 in
  let _ = Test.also_used "hello" in
  ()