type t = { name : string; value : int }

let test1 = 
  {
    name = "test";
    value = 42;
    extra = "bad";  (* This field is unbound *)
  }

let test2 =
  {
    name = "test2";
    value = 100;
    debug;  (* Punned unbound field *)
  }