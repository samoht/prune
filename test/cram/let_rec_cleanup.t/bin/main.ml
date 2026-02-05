let () =
  Printf.printf "expr: %d\n" (Parser.parse_expr "hello");
  Printf.printf "term: %d\n" (Parser.parse_term "world");
  Printf.printf "factor: %d\n" (Parser.parse_factor "!")
