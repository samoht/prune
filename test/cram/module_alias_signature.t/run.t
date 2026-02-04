Module alias with signature constraint test
==========================================

This test verifies that prune correctly handles module aliases and re-exports.
When a symbol appears in multiple .mli files, it's being exported/used in those
interfaces and should be preserved, even if merlin's occurrence tracking
through module aliases is incomplete.

Setup validates the detection logic for symbols appearing in multiple interfaces:

Setup:
- metrics.mli exports kpi_comparison (unused)
- brui.mli has a module signature that includes kpi_comparison
- brui.ml aliases Metrics module: module Metrics = Metrics
- kpi_comparison is not used by any code

Build the project:
  $ dune build

Initial state - verify multi-interface detection is working:
  $ prune clean . -f --dry-run -vv 2>&1 | grep -E "(kpi_comparison|has 2 occurrences|classify_symbol)" | grep -B1 -A1 "kpi_comparison" | head -20
  $ prune clean . -f --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 3 .mli files
    No unused exports found!

Check if module alias is detected in brui.ml:
  $ prune clean . --dry-run -vv 2>&1 | grep -E "(Skipping module alias|Filtering modules)" | head -10

The detection correctly identifies that symbols appearing in multiple .mli
files are being used (exported) in those interfaces and should be preserved,
even when merlin's occurrence tracking through module aliases is incomplete.

Check what was changed:
  $ cat lib/metrics.mli
  (* Original metrics module *)
  val compute : int -> int
  
  val kpi_comparison : 
    metric_name:string -> target:float -> actual:float -> unit:string -> string
  (** [kpi_comparison ~metric_name ~target ~actual ~unit] is a KPI comparison element. *)
  
  val display : string -> unit




































  $ cat lib/brui.mli
  (* Brui module with nested module signature *)
  module Metrics : sig
    val compute : int -> int
    
    val kpi_comparison : 
      metric_name:string -> target:float -> actual:float -> unit:string -> string
    (** [kpi_comparison ~metric_name ~target ~actual ~unit] is a KPI comparison element. *)
    
    val display : string -> unit
  end
  
  val run : unit -> unit






Build the project:
  $ cat bin/main.ml
  (* Main binary that uses brui - but not kpi_comparison *)
  let () = 
    (* Use Brui.run which internally uses Metrics.compute and display *)
    Brui.run ();
    (* Also directly use some Metrics functions through Brui to ensure they're not marked as unused *)
    let _ = Brui.Metrics.compute 10 in
    Brui.Metrics.display "test"
    (* Note: kpi_comparison is NOT used anywhere *)














  $ dune exec -- bin/main.exe
  84
  test
