(* Protocol definition with 4-level nested modules. *)

module Transport = struct
  module Frame = struct
    module Header = struct
      module Flags = struct
        type t = int
        let empty = 0
        let set_urgent t = t lor 1
        let set_compressed t = t lor 2
        let set_encrypted t = t lor 4
        let set_debug t = t lor 8
        let is_urgent t = t land 1 <> 0
        let is_debug t = t land 8 <> 0
        let unused_to_int t = t
      end

      type t = { version : int; flags : Flags.t }
      let create ~version ~flags = { version; flags }
      let version h = h.version
      let flags h = h.flags
      let unused_header_size = 16
    end

    type t = { header : Header.t; payload : string }
    let create ~header ~payload = { header; payload }
    let header f = f.header
    let payload f = f.payload
    let unused_checksum f = String.length f.payload
  end

  let send frame =
    let h = Frame.header frame in
    let v = Frame.Header.version h in
    Printf.sprintf "v%d:%s" v (Frame.payload frame)

  let unused_receive _data = None
end
