(* User management module *)

module Internal : sig
  type t
  val create_user : unit -> t
end = struct
  type stats = {
    login_count : int;
    last_login : float;
  }

  type t = {
    name : string; (* User's name or username *)
    stats : stats; (* User's statistics *)
  }

  let create_user () = { name = "test"; stats = { login_count = 0; last_login = 0.0 } }
end