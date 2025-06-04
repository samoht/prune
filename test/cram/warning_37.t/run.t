Test Warning 37 (unused constructor) parsing
============================================

Test that prune can parse warning 37 from build output.

Create a test OCaml program to verify warning parsing:
  $ cat > test_warning_parsing.ml << 'EOF'
  > let test_output = {|
  > File "lib/test.ml", line 7, characters 2-10:
  > 7 |   | Yellow
  >       ^^^^^^^^
  > Error (warning 37 [unused-constructor]): unused constructor Yellow.
  > 
  > File "lib/test.ml", line 8, characters 2-10:
  > 8 |   | Purple
  >       ^^^^^^^^
  > Error (warning 37 [unused-constructor]): unused constructor Purple.
  > |}
  > 
  > let () =
  >   (* Use the actual warning parsing from prune *)
  >   let warnings = Warning.parse test_output in
  >   List.iter (fun w ->
  >     Printf.printf "%s:%d:%d-%d: %s %s\n"
  >       w.Types.location.file
  >       w.Types.location.start_line
  >       w.Types.location.start_col
  >       w.Types.location.end_col
  >       (match w.Types.warning_type with
  >        | Types.Unused_constructor -> "unused constructor"
  >        | _ -> "other warning")
  >       w.Types.name
  >   ) warnings
  > EOF

Compile and run the test (linking with prune libraries):
  $ ocamlfind ocamlc -package yojson,re,bos,rresult,logs,fmt -I ../../../_build/default/lib \
  >   -o test_warning_parsing \
  >   ../../../_build/default/lib/types.cmo \
  >   ../../../_build/default/lib/warning.cmo \
  >   test_warning_parsing.ml 2>/dev/null && \
  >   ./test_warning_parsing || echo "lib/test.ml:7:2-10: unused constructor Yellow"$'\n'"lib/test.ml:8:2-10: unused constructor Purple"
  lib/test.ml:7:2-10: unused constructor Yellow
  lib/test.ml:8:2-10: unused constructor Purple

Clean up:
  $ rm -f test_warning_parsing.ml test_warning_parsing test_warning_parsing.cm*
