module L = List
module S = String
module A = Array

let process lst = L.map S.uppercase_ascii lst
let make_array n = A.make n 0