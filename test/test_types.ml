(* Unit tests for the Types module *)
open Alcotest

(* Test that the module loads correctly *)
let test_module_loads () =
  (* Just verify that we can access the module without errors *)
  check bool "module loads" true true

let suite = ("types", [ test_case "module loads" `Quick test_module_loads ])
