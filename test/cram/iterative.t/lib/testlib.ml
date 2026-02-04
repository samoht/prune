(* Test case 1: Basic iterative cleanup *)
let unused_export () = 42
let helper_for_unused = 42

(* Test case 2: Chain dependencies *)
let rec chain1 x = chain2 (x + 1)
and chain2 x = chain3 (x * 2)
and chain3 x = chain4 (x - 1)
and chain4 x = chain5 (x / 2)
and chain5 x = x

(* Test case 3: Used chain (entry point used in bin) *)
let rec entry x = step1 x
and step1 x = step2 (x + 10)
and step2 x = step3 (x * 3)
and step3 x = x + 100

(* Test case 4: Internal dependencies *)
let used_internally x = x * 2
let internal_helper x = used_internally x + 10

(* Test case 5: Used in other module *)
let used_in_other x = x + 5

(* Test case 6: Standalone unused *)
let standalone_unused () = "never used"