type config = {
  name : string;
  value : int;
  enabled : bool;
}

val helper : unit -> config
val make_config : string -> int -> bool -> config
val make_config_with_error : string -> int -> bool -> config