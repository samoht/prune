(* Token type for a small language with many unused constructors. *)

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

let to_string = function
  | Int n -> string_of_int n
  | Float f -> string_of_float f
  | String s -> Printf.sprintf "%S" s
  | Ident s -> s
  | Plus -> "+" | Minus -> "-" | Star -> "*" | Slash -> "/"
  | Percent -> "%" | Caret -> "^" | Tilde -> "~" | Bang -> "!"
  | Ampersand -> "&" | Pipe -> "|"
  | LParen -> "(" | RParen -> ")"
  | LBrace -> "{" | RBrace -> "}"
  | LBracket -> "[" | RBracket -> "]"
  | Comma -> "," | Semicolon -> ";" | Colon -> ":" | Dot -> "."
  | Arrow -> "->" | FatArrow -> "=>" | Ellipsis -> "..."
  | EOF -> "<EOF>"

let is_operator = function
  | Plus | Minus | Star | Slash | Percent | Caret | Tilde | Bang
  | Ampersand | Pipe -> true
  | _ -> false

let precedence = function
  | Pipe -> 1
  | Ampersand -> 2
  | Plus | Minus -> 3
  | Star | Slash | Percent -> 4
  | Caret -> 5
  | Tilde | Bang -> 6
  | _ -> 0
