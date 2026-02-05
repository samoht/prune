open Protocol

let () =
  let flags =
    Transport.Frame.Header.Flags.empty
    |> Transport.Frame.Header.Flags.set_urgent
    |> Transport.Frame.Header.Flags.set_compressed
  in
  let header = Transport.Frame.Header.create ~version:1 ~flags in
  let frame = Transport.Frame.create ~header ~payload:"hello world" in
  let result = Transport.send frame in
  Printf.printf "Sent: %s\n" result;
  Printf.printf "Urgent: %b\n"
    (Transport.Frame.Header.Flags.is_urgent
       (Transport.Frame.Header.flags header))
