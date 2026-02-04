let main_function x = "Hello " ^ x
let test_helper () = "test"
let production_helper x = x * 2
let another_function x = not x
let create_test_data n = List.init n (fun i -> string_of_int i)
let process_data lst = String.concat ", " lst
let utility x = x *. 2.0
let completely_unused x = print_endline x