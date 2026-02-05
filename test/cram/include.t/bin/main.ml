let () =
  let x = Testlib.Extended.base_used 41 in
  let s = Testlib.Extended.ext_used x in
  let n = Testlib.With_sig.Sub.sub_used s in
  let y = Testlib.With_sig.top_used n in
  Printf.printf "Result: %d\n" y
