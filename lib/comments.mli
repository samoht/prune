(** Source comment scanning utilities for comments not in the AST

    This module handles detection of source-level comments (* ... *) that are
    not part of the OCaml AST. Doc comments (** ... *) attached to items become
    attributes and are handled through the AST, but floating doc comments and
    regular comments need this scanner.

    TODO: Remove this module once OCaml parser includes all comments in AST *)

val extend_location_with_comments :
  Cache.t -> string -> Types.location -> Types.location
(** [extend_location_with_comments cache file location] extends the given
    location to include any source-level comments (both doc and regular) that
    immediately precede or follow the location. *)
