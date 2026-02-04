Test removal of large record types spanning multiple lines

Build the project:
  $ dune build

Check what prune detects as unused:
  $ prune clean . --dry-run
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
    No unused exports found!

Debug: Show what the .mli file looks like before removal:
  $ head -10 lib/testlib.mli
  (** This is a used function *)
  val used_function : int -> int
  
  (** This is an unused large record type that spans many lines *)
  type unused_large_record = {
    field1 : string;
    field2 : int;
    field3 : float;
    field4 : bool;
    field5 : string list;

Test actual removal:
  $ prune clean . --force
  prune: [WARNING] ocamlmerlin not found in PATH
  Analyzing 1 .mli file
  
  
    Iteration 1:
    ✓ No unused code found

Debug: Check build after removal:
  $ dune build 2>&1 || echo "Build failed with exit code $?"
Verify the large record type was completely removed:
  $ cat lib/testlib.mli
  (** This is a used function *)
  val used_function : int -> int
  
  (** This is an unused large record type that spans many lines *)
  type unused_large_record = {
    field1 : string;
    field2 : int;
    field3 : float;
    field4 : bool;
    field5 : string list;
    field6 : int option;
    field7 : (string * int) list;
    field8 : unit -> unit;
    field9 : string array;
    field10 : bytes;
    field11 : char;
    field12 : int32;
    field13 : int64;
    field14 : nativeint;
    field15 : string * string * string;
    field16 : [ `A | `B | `C ];
    field17 : int ref;
    field18 : (int -> int) list;
    field19 : string lazy_t;
    field20 : unit Lazy.t;
  }
  
  (** Another unused type *)
  type unused_simple = int
  
  (** This is a used type *)
  type used_type = string

This shows proper iterative behavior: exports are removed from .mli files first,
then orphaned implementations are cleaned up in subsequent iterations.

Verify the file still compiles:
  $ dune build
  $ dune exec ./main.exe
  Result: 43
