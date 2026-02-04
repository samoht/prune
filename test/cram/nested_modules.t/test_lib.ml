module Top = struct
  let top_used () = ()
  let top_unused x = x + 1

  type 'a config = {
    value : 'a;
    label : string;
  }

  type unused_type = int

  module Store = struct
    let state = ref 0
    let get () = !state
    let set v = state := v
    let update f = state := f !state
  end

  (* This function uses Store internally, but Store functions aren't used externally *)
  let get_count () = Store.get ()
  let increment () = Store.update (fun x -> x + 1)

  module Level1 = struct
    let l1_used s = s ^ "!"
    let l1_unused b = not b
    
    module Level2 = struct
      let l2_used f = f *. 2.0
      let l2_unused c = Char.uppercase_ascii c
      
      let make_config v = { value = v; label = "test" }
    end
  end
  
  module CompletelyUnused = struct
    let unused1 x = x + 1
    let unused2 s = s ^ "unused"
    
    module AlsoUnused = struct
      let unused3 b = not b
      type unused_t = float
    end
  end
end