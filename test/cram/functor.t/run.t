Test functor handling
=====================

This test verifies prune handles functors correctly. The store library
defines a functor with a KEY module type and Make functor. The main
binary uses Make but never calls debug_dump or to_string.

Build the project (debug_dump is unused, triggering w32 in bin):

  $ dune build

Run prune:

  $ prune clean . --dry-run
  Analyzing 1 .mli file
  lib/store.mli:5:2-29: unused value compare
  lib/store.mli:6:2-29: unused value to_string
  lib/store.mli:12:2-18: unused value empty
  lib/store.mli:13:2-37: unused value add
  lib/store.mli:14:2-41: unused value find_opt
  lib/store.mli:15:2-24: unused value size
  lib/store.mli:16:2-33: unused value debug_dump
  Found 7 unused exports

  $ prune clean . --force
  Analyzing 1 .mli file
  
  
    Iteration 1:
  Removing 7 unused exports...
  ✓ lib/store.mli
  Build failed with 2 errors - full output:
  File "bin/main.ml", line 10, characters 10-24:
  10 |   let s = IntStore.empty in
                 ^^^^^^^^^^^^^^
  Error: Unbound value IntStore.empty
  File "lib/store.ml", line 1:
  Error: The implementation lib/store.ml
         does not match the interface lib/store.mli: 
         Module type declarations do not match:
           module type KEY =
             sig
               type t
               val compare : t -> t -> int
               val to_string : t -> string
             end
         does not match
           module type KEY = sig type t end
         The second module type is not included in the first
         At position module type KEY = <here>
         Module types do not match:
           sig type t end
         is not equal to
           sig
             type t
             val compare : t -> t -> int
             val to_string : t -> string
           end
         At position module type KEY = <here>
         The value compare is required but not provided
         File "lib/store.ml", line 5, characters 2-29: Expected declaration
         The value to_string is required but not provided
         File "lib/store.ml", line 6, characters 2-29: Expected declaration
  [1]

Verify the build still works after cleanup:

  $ dune build
  File "bin/main.ml", line 10, characters 10-24:
  10 |   let s = IntStore.empty in
                 ^^^^^^^^^^^^^^
  Error: Unbound value IntStore.empty
  File "lib/store.ml", line 1:
  Error: The implementation lib/store.ml
         does not match the interface lib/store.mli: 
         Module type declarations do not match:
           module type KEY =
             sig
               type t
               val compare : t -> t -> int
               val to_string : t -> string
             end
         does not match
           module type KEY = sig type t end
         The second module type is not included in the first
         At position module type KEY = <here>
         Module types do not match:
           sig type t end
         is not equal to
           sig
             type t
             val compare : t -> t -> int
             val to_string : t -> string
           end
         At position module type KEY = <here>
         The value compare is required but not provided
         File "lib/store.ml", line 5, characters 2-29: Expected declaration
         The value to_string is required but not provided
         File "lib/store.ml", line 6, characters 2-29: Expected declaration
  [1]

  $ dune exec ./bin/main.exe
  File "bin/main.ml", line 10, characters 10-24:
  10 |   let s = IntStore.empty in
                 ^^^^^^^^^^^^^^
  Error: Unbound value IntStore.empty
  File "lib/store.ml", line 1:
  Error: The implementation lib/store.ml
         does not match the interface lib/store.mli: 
         Module type declarations do not match:
           module type KEY =
             sig
               type t
               val compare : t -> t -> int
               val to_string : t -> string
             end
         does not match
           module type KEY = sig type t end
         The second module type is not included in the first
         At position module type KEY = <here>
         Module types do not match:
           sig type t end
         is not equal to
           sig
             type t
             val compare : t -> t -> int
             val to_string : t -> string
           end
         At position module type KEY = <here>
         The value compare is required but not provided
         File "lib/store.ml", line 5, characters 2-29: Expected declaration
         The value to_string is required but not provided
         File "lib/store.ml", line 6, characters 2-29: Expected declaration
  [1]
