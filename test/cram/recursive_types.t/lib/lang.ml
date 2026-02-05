(* A small expression language with mutually recursive types. *)

type expr =
  | Lit of int
  | Add of expr * expr
  | Mul of expr * expr
  | Neg of expr
  | If of cond * expr * expr
  | Block of stmt list * expr
  | Unused_debug_expr of string

and cond =
  | True
  | False
  | Eq of expr * expr
  | Lt of expr * expr
  | And of cond * cond
  | Or of cond * cond
  | Not of cond
  | Unused_debug_cond of string

and stmt =
  | Let of string * expr
  | Print of expr
  | Assert of cond
  | Unused_debug_stmt of string

let env = Hashtbl.create 16

let rec eval = function
  | Lit n -> n
  | Add (a, b) -> eval a + eval b
  | Mul (a, b) -> eval a * eval b
  | Neg e -> -(eval e)
  | If (c, t, f) -> if eval_cond c then eval t else eval f
  | Block (stmts, e) ->
      List.iter exec_stmt stmts;
      eval e
  | Unused_debug_expr _ -> 0

and eval_cond = function
  | True -> true
  | False -> false
  | Eq (a, b) -> eval a = eval b
  | Lt (a, b) -> eval a < eval b
  | And (a, b) -> eval_cond a && eval_cond b
  | Or (a, b) -> eval_cond a || eval_cond b
  | Not c -> not (eval_cond c)
  | Unused_debug_cond _ -> false

and exec_stmt = function
  | Let (name, e) -> Hashtbl.replace env name (eval e)
  | Print e -> Printf.printf "%d\n" (eval e)
  | Assert c -> assert (eval_cond c)
  | Unused_debug_stmt _ -> ()

let rec pp_expr ppf = function
  | Lit n -> Format.fprintf ppf "%d" n
  | Add (a, b) -> Format.fprintf ppf "(%a + %a)" pp_expr a pp_expr b
  | Mul (a, b) -> Format.fprintf ppf "(%a * %a)" pp_expr a pp_expr b
  | Neg e -> Format.fprintf ppf "(-%a)" pp_expr e
  | If (_, t, _) -> Format.fprintf ppf "(if ... %a ...)" pp_expr t
  | Block (_, e) -> Format.fprintf ppf "(block ... %a)" pp_expr e
  | Unused_debug_expr s -> Format.fprintf ppf "(debug %s)" s
