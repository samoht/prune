(* Use some functions to prevent them from being marked as unused *)
let () =
  Test_lib.Top.top_used ();
  let _ = Test_lib.Top.Level1.l1_used "hello" in
  let _ = Test_lib.Top.Level1.Level2.l2_used 1.5 in
  let _ = Test_lib.Top.Level1.Level2.make_config 42 in
  let _ = Test_mod.M.foo 1 in
  (* Note: get_count and increment are NOT used externally, 
     only internally by test_lib.ml *)
  ()