(* Brui module with nested module signature *)
module Metrics : sig
  val compute : int -> int
  
  val kpi_comparison : 
    metric_name:string -> target:float -> actual:float -> unit:string -> string
  (** [kpi_comparison ~metric_name ~target ~actual ~unit] is a KPI comparison element. *)
  
  val display : string -> unit
end

val run : unit -> unit