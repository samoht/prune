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
  prune: [DEBUG]   [2] kpi_comparison (value) at lib/metrics.mli:4:0-5:77
  prune: [DEBUG]   [4] kpi_comparison (value) at lib/brui.mli:5:2-6:79
  prune: [INFO] Checking occurrences for kpi_comparison at lib/brui.mli:5:2-6:79 (adjusted to 5:6) with query: occurrences -identifier-at 5:6 -scope project
  prune: [DEBUG] Merlin response for kpi_comparison: {
  prune: [DEBUG] Extracted from merlin for kpi_comparison: count=2, locations=[lib/brui.mli:5:6-20; lib/metrics.mli:4:4-18]
  prune: [DEBUG]   Analyzing 2 occurrences for value kpi_comparison
  prune: [DEBUG]   Symbol kpi_comparison: mli_in_defining=1, external=1
  prune: [DEBUG] Symbol kpi_comparison appears in multiple .mli files with only 2 occurrences, likely a re-export
  prune: [DEBUG] Symbol kpi_comparison: 2 occurrences, usage=used, locations=lib/brui.mli:5:6-20, lib/metrics.mli:4:4-18
  prune: [INFO] OCCURRENCE MAPPING: kpi_comparison@lib/brui.mli:5:2-6:79 -> 2 occurrences
  prune: [INFO] Checking occurrences for kpi_comparison at lib/metrics.mli:4:0-5:77 (adjusted to 4:4) with query: occurrences -identifier-at 4:4 -scope project
  prune: [DEBUG] Merlin response for kpi_comparison: {
  prune: [DEBUG] Extracted from merlin for kpi_comparison: count=2, locations=[lib/metrics.mli:4:4-18; lib/metrics.ml:4:4-18]
  prune: [DEBUG]   Analyzing 2 occurrences for value kpi_comparison
  prune: [DEBUG]   Symbol kpi_comparison: mli_in_defining=1, external=0
  prune: [DEBUG]   No external uses for kpi_comparison, in_defining_mli=1, in_defining_ml=1
  prune: [DEBUG]   -> Marking kpi_comparison as Unused
  prune: [DEBUG] Symbol kpi_comparison: 2 occurrences, usage=unused, locations=lib/metrics.mli:4:4-18, lib/metrics.ml:4:4-18
  prune: [INFO] OCCURRENCE MAPPING: kpi_comparison@lib/metrics.mli:4:0-5:77 -> 2 occurrences
  prune: [INFO] Found symbols in multiple .mli files: display, compute, kpi_comparison
  $ prune clean . -f --dry-run
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
