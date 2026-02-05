(** Token type for a small language with many unused constructors. *)

type t =
  | Int of int
  | Float of float
  | String of string
  | Ident of string
  | Plus
  | Minus
  | Star
  | Slash
  | Percent
  | Caret
  | Tilde
  | Bang
  | Ampersand
  | Pipe
  | LParen
  | RParen
  | LBrace
  | RBrace
  | LBracket
  | RBracket
  | Comma
  | Semicolon
  | Colon
  | Dot
  | Arrow
  | FatArrow
  | Ellipsis
  | EOF

val to_string : t -> string
val is_operator : t -> bool
val precedence : t -> int
