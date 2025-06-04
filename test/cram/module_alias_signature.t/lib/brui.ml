(* Brui implementation with module alias *)
module Metrics = Metrics

let run () =
  let result = Metrics.compute 42 in
  Metrics.display (string_of_int result)
  (* Note: kpi_comparison is not used *)