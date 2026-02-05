(* Output formatting and display module *)

type mode = Normal | Quiet | Verbose | Json

let current_mode = ref Normal
let set_mode mode = current_mode := mode

(* Styles using Tty *)
let style_green = Tty.Style.(fg Tty.Color.green)
let style_yellow = Tty.Style.(fg Tty.Color.yellow)
let style_red = Tty.Style.(fg Tty.Color.red)
let style_blue = Tty.Style.(fg Tty.Color.blue)

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

(* Progress indicators - delegate to Tty.Progress *)
type progress = Tty.Progress.t

let progress ?total () =
  let enabled = !current_mode = Normal && Tty.Width.is_tty () in
  Tty.Progress.create ~style:`ASCII ~enabled ?total ""

let update_progress p msg = Tty.Progress.message p msg
let set_progress_current p n = Tty.Progress.set p n
let clear_progress p = Tty.Progress.clear p
