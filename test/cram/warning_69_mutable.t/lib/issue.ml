module Internal : sig 
  type music_library
  val create_library : int list -> music_library  
  val get_users : music_library -> int list
end = struct
  type music_library = {
    mutable users : int list;

  }

  let create_library users = { users;             }

  let get_users lib = lib.users
end