module type S = sig
  val common : int -> int
end

module Sub = struct
  let common x = x * 2
  let sub_used s = String.length s
  let sub_unused x = x + 1
end

let top_used x = x + 10
let top_unused s = s ^ "?"
