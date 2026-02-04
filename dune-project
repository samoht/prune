(lang dune 3.0)
(name prune)
(generate_opam_files true)

(source
 (github samoht/prune))

(authors "the Prune developers")

(maintainers "Thomas Gazagnaire")

(license ISC)

(package
 (name prune)
 (synopsis "Find unused exports in OCaml interface files")
 (description "Prune analyzes OCaml projects to find exported values and types
in .mli files that are never used elsewhere in the codebase. It leverages
merlin for accurate symbol analysis across dune projects.")
 (depends
  (ocaml (>= 5.3))
  dune
  merlin
  (yojson (>= 1.6))
  (bos (>= 0.2))
  (cmdliner (>= 1.3.0))
  (rresult (>= 0.7))
  (logs (>= 0.8.0))
  (fmt (>= 0.8))
  (re (>= 1.9))
  ppxlib
  (alcotest :with-test)))