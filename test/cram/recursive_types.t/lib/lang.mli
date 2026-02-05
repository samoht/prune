(** A small expression language with mutually recursive types. *)

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

val eval : expr -> int
val eval_cond : cond -> bool
val pp_expr : Format.formatter -> expr -> unit
