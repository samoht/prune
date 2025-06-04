(* Original metrics implementation *)
let compute x = x * 2

let kpi_comparison ~metric_name ~target ~actual ~unit =
  Printf.sprintf "%s: %.2f/%.2f %s" metric_name actual target unit
  
let display s = print_endline s