(** Display symbol occurrence statistics *)

type format = Cli  (** Terminal output *) | Html  (** Static HTML website *)

val run :
  format:format ->
  output_dir:string option ->
  root_dir:string ->
  mli_files:string list ->
  (unit, [ `Msg of string ]) result
(** Analyze and display symbol occurrences
    @param format Output format (CLI or HTML)
    @param output_dir Directory for HTML output (only used for HTML format)
    @param root_dir Root directory of the project
    @param mli_files List of .mli files to analyze
    @return unit on success, error otherwise *)
