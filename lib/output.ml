(* Output formatting and display module *)

type output_mode = Normal | Quiet | Verbose | Json

let current_mode = ref Normal
let set_mode mode = current_mode := mode

(* ANSI color codes *)
let green = "\027[32m"
let yellow = "\027[33m"
let red = "\027[31m"
let blue = "\027[34m"
let reset = "\027[0m"
let is_tty = Unix.isatty Unix.stdout
let with_color color s = if is_tty then color ^ s ^ reset else s

(* Terminal width caching *)
let terminal_width = ref None

let get_terminal_width () =
  match !terminal_width with
  | Some w -> w
  | None ->
      let width =
        try
          let ic = Unix.open_process_in "tput cols 2>/dev/null" in
          let w = int_of_string (input_line ic) in
          close_in ic;
          w
        with _ -> 80 (* Safe default if tput fails *)
      in
      terminal_width := Some width;
      width

(* Structured output *)
let header fmt =
  if !current_mode <> Quiet then
    Format.kasprintf (fun s -> Format.printf "%s@." (with_color blue s)) fmt
  else Format.ifprintf Format.std_formatter fmt

let section fmt =
  if !current_mode <> Quiet then
    Format.kasprintf (fun s -> Format.printf "  %s@." s) fmt
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
    let width = get_terminal_width () in
    match p.total with
    | Some total ->
        let pct = p.current * 100 / total in
        let prefix = Format.sprintf "[%3d%%] " pct in
        let prefix_len = String.length prefix in
        let max_msg_len = max 1 (width - prefix_len - 1) in
        let truncated_msg =
          if String.length msg > max_msg_len then
            String.sub msg 0 (max_msg_len - 3) ^ "..."
          else msg
        in
        (* Pad message to full width to overwrite any remnants *)
        let full_msg = prefix ^ truncated_msg in
        let padded_msg =
          if String.length full_msg < width then
            full_msg ^ String.make (width - String.length full_msg) ' '
          else full_msg
        in
        Format.printf "\r%s%!" padded_msg
    | None ->
        let max_msg_len = max 1 (width - 1) in
        let truncated_msg =
          if String.length msg > max_msg_len then
            String.sub msg 0 (max_msg_len - 3) ^ "..."
          else msg
        in
        (* Pad message to full width to overwrite any remnants *)
        let padded_msg =
          if String.length truncated_msg < width then
            truncated_msg
            ^ String.make (width - String.length truncated_msg) ' '
          else truncated_msg
        in
        Format.printf "\r%s%!" padded_msg

let set_progress_current p n =
  p.current <- n;
  update_progress p p.message

let clear_progress _ =
  if !current_mode = Normal && is_tty then
    let width = get_terminal_width () in
    Format.printf "\r%s\r%!" (String.make width ' ')
