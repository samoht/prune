(** Test library to demonstrate nested module handling *)

(** Everything wrapped in a top-level module to test type preservation *)
module Top : sig
  (** Top-level values *)
  val top_used : unit -> unit
  val top_unused : int -> int

  (** A type that is used in nested modules below *)
  type 'a config = {
    value : 'a;
    label : string;
  }

  (** An unused type *)
  type unused_type = int

  (** Internal store module - functions only used within this module *)
  module Store : sig
    val get : unit -> int
    val set : int -> unit
    val update : (int -> int) -> unit
  end

  (** Functions that use Store internally *)
  val get_count : unit -> int
  val increment : unit -> unit

  (** First level module *)
  module Level1 : sig
    val l1_used : string -> string
    val l1_unused : bool -> bool
    
    (** Nested module *)
    module Level2 : sig
      val l2_used : float -> float
      val l2_unused : char -> char
      
      (** Function using parent module's config type *)
      val make_config : 'a -> 'a config
    end
  end
  
  (** Module where everything is unused *)
  module CompletelyUnused : sig
    val unused1 : int -> int
    val unused2 : string -> string
    
    (** Nested module also completely unused *)
    module AlsoUnused : sig
      val unused3 : bool -> bool
      type unused_t = float
    end
  end
end