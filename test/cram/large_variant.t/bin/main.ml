(* Only uses a subset of the token constructors *)
let tokens =
  [ Token.Int 42; Token.Plus; Token.Ident "x"; Token.Star;
    Token.LParen; Token.Float 3.14; Token.RParen; Token.EOF ]

let () =
  List.iter (fun t ->
    Printf.printf "%s (op=%b, prec=%d)\n"
      (Token.to_string t) (Token.is_operator t) (Token.precedence t))
    tokens
