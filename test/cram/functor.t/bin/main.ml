module IntKey = struct
  type t = int
  let compare = Int.compare
  let to_string = string_of_int
end

module IntStore = Store.Make (IntKey)

let () =
  let s = IntStore.empty in
  let s = IntStore.add 1 "one" s in
  let s = IntStore.add 2 "two" s in
  match IntStore.find_opt 1 s with
  | Some v -> Printf.printf "Found: %s (size: %d)\n" v (IntStore.size s)
  | None -> Printf.printf "Not found\n"
