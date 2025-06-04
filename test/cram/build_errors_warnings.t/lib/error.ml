open List
type t = { unused : int }
let f x = x.nonexistent  (* This will cause a build error *)