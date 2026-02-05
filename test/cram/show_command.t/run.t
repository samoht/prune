Test show command functionality
===============================

This test verifies that the show command displays symbol occurrence statistics.

Create a simple project with some symbols:
  $ cat > lib.mli << EOF
  > (** A value that is used *)
  > val used_value : int -> int
  > 
  > (** A value that is unused *)  
  > val unused_value : string -> string
  > 
  > (** A type that is used *)
  > type used_type = int
  > 
  > (** A type that is unused *)
  > type unused_type = string
  > EOF

  $ cat > lib.ml << EOF
  > let used_value x = x * 2
  > let unused_value s = s ^ s
  > type used_type = int
  > type unused_type = string
  > EOF

  $ cat > main.ml << EOF
  > open Lib
  > 
  > let result = used_value 21
  > let t : used_type = 42
  > 
  > let () = 
  >   Printf.printf "Result: %d\n" result;
  >   Printf.printf "Type value: %d\n" t
  > EOF

  $ cat > dune-project << EOF
  > (lang dune 3.0)
  > EOF

  $ cat > dune << EOF
  > (library
  >  (name lib)
  >  (modules lib))
  > 
  > (executable
  >  (name main)
  >  (modules main)
  >  (libraries lib))
  > EOF

Build the project:
  $ dune build

Test CLI output format:
  $ prune show . --format cli
  Analyzing 1 .mli file
  Symbol Occurrence Report
  ========================
  
  Total symbols: 4
  Used symbols: 0
  Unused symbols: 4
  Used only in excluded dirs: 0
  
  File: lib.mli
      type unused_type (1 occurrences) - unused
      value unused_value (1 occurrences) - unused
      type used_type (1 occurrences) - unused
      value used_value (1 occurrences) - unused
    
  

Test HTML output format:
  $ prune show . --format html -o report
  Analyzing 1 .mli file
  HTML report generated: report/index.html

Verify HTML file was created:
  $ test -f report/index.html && echo "HTML file created"
  HTML file created

Check HTML contains expected content:
  $ grep -q "Prune Symbol Occurrence Report" report/index.html && echo "Has title"
  Has title
  $ grep -q "used_value" report/index.html && echo "Has used_value"
  Has used_value
  $ grep -q "unused_type" report/index.html && echo "Has unused_type"  
  Has unused_type

Test with specific file:
  $ prune show lib.mli --format cli | grep "Total symbols:"
  Total symbols: 4

Test with non-existent file:
  $ prune show nonexistent.mli --format cli
  Analyzing 0 .mli files
  Error: No .mli files found to analyze
  [1]
