(* Output formatting and display module *)

type output_mode = Normal | Quiet | Verbose | Json

let current_mode = ref Normal
let set_mode mode = current_mode := mode
let get_mode () = !current_mode

(* ANSI color codes *)
let green = "\027[32m"
let yellow = "\027[33m"
let red = "\027[31m"
let blue = "\027[34m"
let reset = "\027[0m"
let is_tty = Unix.isatty Unix.stdout
let with_color color s = if is_tty then color ^ s ^ reset else s

(* Basic output functions *)
let print fmt = Format.printf fmt
let eprint fmt = Format.eprintf fmt

let verbose fmt =
  if !current_mode = Verbose then Format.printf fmt
  else Format.ifprintf Format.std_formatter fmt

(* Structured output *)
let header fmt =
  if !current_mode <> Quiet then
    Format.kasprintf (fun s -> Format.printf "%s@." (with_color blue s)) fmt
  else Format.ifprintf Format.std_formatter fmt

let section fmt =
  if !current_mode <> Quiet then
    Format.kasprintf (fun s -> Format.printf "  %s@." s) fmt
  else Format.ifprintf Format.std_formatter fmt

let info fmt =
  if !current_mode <> Quiet then Format.printf fmt
  else Format.ifprintf Format.std_formatter fmt

let success fmt =
  if !current_mode <> Quiet then
    Format.kasprintf (fun s -> Format.printf "%s@." (with_color green s)) fmt
  else Format.ifprintf Format.std_formatter fmt

let warning fmt =
  Format.kasprintf
    (fun s -> Format.eprintf "%s@." (with_color yellow ("Warning: " ^ s)))
    fmt

let error fmt =
  Format.kasprintf
    (fun s -> Format.eprintf "%s@." (with_color red ("Error: " ^ s)))
    fmt

(* Progress indicators *)
type progress = {
  mutable current : int;
  mutable message : string;
  total : int option;
}

let create_progress ?total () = { current = 0; message = ""; total }

let update_progress p msg =
  p.message <- msg;
  if !current_mode = Normal && is_tty then
    match p.total with
    | Some total ->
        let pct = p.current * 100 / total in
        Format.printf "\r[%3d%%] %s%!" pct msg
    | None -> Format.printf "\r%s%!" msg

let set_progress_current p n =
  p.current <- n;
  update_progress p p.message

let clear_progress _ =
  if !current_mode = Normal && is_tty then
    Format.printf "\r%s\r%!" (String.make 80 ' ')
