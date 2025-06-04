open Mylib

let test_main () =
  assert (main_function "test" = "Hello test");
  assert (test_helper () = "test")

let test_data_creation () =
  let data = create_test_data 3 in
  assert (List.length data = 3);
  assert (process_data data = "0, 1, 2")

let () =
  test_main ();
  test_data_creation ();
  print_endline "All tests passed"