(** Protocol definition with 4-level nested modules. *)

module Transport : sig
  module Frame : sig
    module Header : sig
      module Flags : sig
        type t
        val empty : t
        val set_urgent : t -> t
        val set_compressed : t -> t
        val set_encrypted : t -> t
        val set_debug : t -> t
        val is_urgent : t -> bool
        val is_debug : t -> bool
        val unused_to_int : t -> int
      end

      type t
      val create : version:int -> flags:Flags.t -> t
      val version : t -> int
      val flags : t -> Flags.t
      val unused_header_size : int
    end

    type t
    val create : header:Header.t -> payload:string -> t
    val header : t -> Header.t
    val payload : t -> string
    val unused_checksum : t -> int
  end

  val send : Frame.t -> string
  val unused_receive : string -> Frame.t option
end
