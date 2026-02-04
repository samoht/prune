(** Test case 1: Basic unused export *)
val unused_export : unit -> int

(** Test case 2: Unused chain start *)
val chain1 : int -> int

(** Test case 3: Used chain (entry used in bin) *)
val entry : int -> int
val step1 : int -> int  
val step2 : int -> int
val step3 : int -> int

(** Test case 4: Used internally by internal_helper *)
val used_internally : int -> int

(** Test case 5: Used in other module *)
val used_in_other : int -> int

(** Test case 6: Standalone unused *)
val standalone_unused : unit -> string