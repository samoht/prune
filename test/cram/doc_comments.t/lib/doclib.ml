let used () = ()
let unused_leading () = 42
let unused_trailing x = x * 2
let unused_mixed s = String.uppercase_ascii s
let unused_multiline () = "test"
let used_with_docs x = x + 1