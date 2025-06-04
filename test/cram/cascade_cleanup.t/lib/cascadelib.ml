(* Implementation *)

(* Internal helper - not exported *)
let internal_helper x = x * 2

(* Wrapper is exported but unused externally, only uses internal_helper *)
let wrapper x = internal_helper x + 1

let main () = 
  Printf.printf "Main called\n"