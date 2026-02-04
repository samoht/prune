(** Display symbol occurrence statistics *)

type format = Cli  (** Terminal output *) | Html  (** Static HTML website *)

val run :
  format:format ->
  output_dir:string option ->
  root_dir:string ->
  mli_files:string list ->
  (unit, [ `Msg of string ]) result
(** [run ~format ~output_dir ~root_dir ~mli_files] analyzes and displays symbol
    occurrences. *)
