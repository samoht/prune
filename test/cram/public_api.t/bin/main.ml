let () =
  let n = Testlib.Api.create "hello" in
  let x = Testlib.Internal.helper n in
  Printf.printf "Result: %d, version: %s\n" x Testlib.Api.version
