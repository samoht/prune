(* Output formatting and display module *)

type mode = Normal | Quiet | Verbose | Json

let current_mode = ref Normal
let set_mode mode = current_mode := mode

(* Styles using Tty *)
let style_green = Tty.Style.(fg Tty.Color.green)
let style_yellow = Tty.Style.(fg Tty.Color.yellow)
let style_red = Tty.Style.(fg Tty.Color.red)
let style_blue = Tty.Style.(fg Tty.Color.blue)
let is_tty = Unix.isatty Unix.stdout

(* Structured output *)
let header fmt =
  if !current_mode <> Quiet then
    Fmt.kstr
      (fun s -> Fmt.pr "%a@." (Tty.Style.styled style_blue Fmt.string) s)
      fmt
  else Fmt.kstr ignore fmt

let section fmt =
  if !current_mode <> Quiet then Fmt.kstr (fun s -> Fmt.pr "  %s@." s) fmt
  else Fmt.kstr ignore fmt

let success fmt =
  if !current_mode <> Quiet then
    Fmt.kstr
      (fun s -> Fmt.pr "%a@." (Tty.Style.styled style_green Fmt.string) s)
      fmt
  else Fmt.kstr ignore fmt

let warning fmt =
  Fmt.kstr
    (fun s ->
      Fmt.epr "%a@." (Tty.Style.styled style_yellow Fmt.string) ("Warning: " ^ s))
    fmt

let error fmt =
  Fmt.kstr
    (fun s ->
      Fmt.epr "%a@." (Tty.Style.styled style_red Fmt.string) ("Error: " ^ s))
    fmt

(* Progress indicators *)
type progress = {
  mutable current : int;
  mutable message : string;
  total : int option;
}

let progress ?total () = { current = 0; message = ""; total }

(* Terminal width detection *)
let cached_terminal_width = ref None

let terminal_width () =
  match !cached_terminal_width with
  | Some w -> w
  | None ->
      let width =
        try
          let ic = Unix.open_process_in "tput cols 2>/dev/null" in
          let w = int_of_string (input_line ic) in
          close_in ic;
          w
        with End_of_file | Failure _ | Sys_error _ -> 80
      in
      cached_terminal_width := Some width;
      width

let update_progress p msg =
  p.message <- msg;
  if !current_mode = Normal && is_tty then
    let width = terminal_width () in
    match p.total with
    | Some total ->
        let pct = p.current * 100 / total in
        let prefix = Fmt.str "[%3d%%] " pct in
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
        Fmt.pr "\r%s%!" padded_msg
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
        Fmt.pr "\r%s%!" padded_msg

let set_progress_current p n =
  p.current <- n;
  update_progress p p.message

let clear_progress _ =
  if !current_mode = Normal && is_tty then
    let width = terminal_width () in
    Fmt.pr "\r%s\r%!" (String.make width ' ')
