(** Warning parsing and handling for prune

    This module parses compiler warnings and errors from dune build output.

    {2 Location precision in compiler warnings}

    The OCaml compiler provides different levels of location precision for
    different warnings. Understanding what the location points to is crucial for
    determining whether we need additional tools (merlin) to find the complete
    construct to remove.

    {3 Warnings that point to the COMPLETE construct (can be removed directly)}

    {ul
     {- **Warning 33 (unused open)**: Points to the entire open statement
        Example: "File \"lib/foo.ml\", line 3, characters 0-15:"
        {[
          open Module  (* characters 0-15 cover the whole statement *)
          ^^^^^^^^^^^^
        ]}
     }
    }

    {ul
     {- **Warning 34 (unused type)**: Points to the entire type definition
        Example: "File \"lib/foo.mli\", line 5, characters 0-24:"
        {[
          type t = int  (* characters 0-24 cover the whole definition *)
          ^^^^^^^^^^^^
        ]}
     }
    }

    {ul
     {- **Warning 69 (unused field)**: Points to the complete field definition
        within a record type Example: "File \"lib/foo.ml\", line 8, characters
        2-20:"
        {[
          type t = {
            field : string;  (* characters 2-20 cover the entire "field : string;" *)
            ^^^^^^^^^^^^^^^^^^
            other : int;
          }
        ]}
        Note: Character-level removal is used (replacing with spaces) to
        preserve the record structure and avoid syntax errors
     }
    }

    {3 Warnings that point to JUST THE IDENTIFIER (need merlin to find full
    construct)}

    {ul
     {- **Warning 32 (unused value)**: Points only to the value name Example:
        "File \"lib/foo.ml\", line 15, characters 4-17:"
        {[
          let unused_value = complex_expression  (* characters 4-17 cover only "unused_value" *)
              ^^^^^^^^^^^^
        ]}
        Action needed: Use merlin enclosing to find the complete let binding
     }
    }

    {3 Errors requiring special handling}

    - **Signature mismatch errors**: Points to declaration in .mli file Example:
      "File \"lib/foo.mli\", line 2, characters 0-35:" Action: For .mli files,
      use merlin outline (already have full bounds)

    {ul
     {- **Unbound record field errors**: Points to just the field name in record
        construction Example: "File \"lib/foo.ml\", line 10, characters 35-42:"
        {[
          let r = { x = 1; y = 2; unbound = 3 }  (* characters 35-42 point to "unbound" only *)
                                   ^^^^^^^
        ]}
        Action needed: Custom parsing to find and remove the entire field
        assignment "unbound = 3" (not just "unbound") to maintain valid syntax
     }
    }

    {2 Summary of location handling}

    | Warning Type | Location Points To | Additional Processing Needed |
    |--------------|-------------------|------------------------------| |
    Warning 32 | Identifier only | Merlin enclosing for full binding | | Warning
    33 | Full statement | None (direct removal) | | Warning 34 | Full definition
    | None (direct removal) | | Warning 69 | Full field def | None
    (character-level removal) | | Sig mismatch | Full declaration | None for
    .mli files | | Unbound field| Field name only | Custom parsing for field
    assignment | *)

open Types

val parse : string -> warning_info list
(** [parse output] parses all warning 32/34 messages from build output. *)
