(* Progress display that delegates to the CLI output system *)

type t = { internal : Output.progress; total : int }

let pp fmt progress = Fmt.pf fmt "<progress: %d total>" progress.total

let v ~total =
  let internal =
    if total > 0 then Output.progress ~total () else Output.progress ()
  in
  { internal; total }

let update progress ~current message =
  Output.set_progress_current progress.internal current;
  Output.update_progress progress.internal message

let clear progress = Output.clear_progress progress.internal
