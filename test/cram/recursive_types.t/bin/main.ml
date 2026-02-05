open Lang

let () =
  let program =
    Block
      ( [ Let ("x", Lit 10); Print (Add (Lit 1, Lit 2)); Assert (Lt (Lit 1, Lit 5)) ],
        If (Eq (Lit 3, Add (Lit 1, Lit 2)), Mul (Lit 6, Lit 7), Neg (Lit 99)) )
  in
  let result = eval program in
  Format.printf "Result: %d@." result;
  Format.printf "Expr: %a@." pp_expr (Add (Lit 1, Mul (Lit 2, Lit 3)))
