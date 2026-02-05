Test large variant type with many unused constructors
=====================================================

This test has a token type with 28 constructors. The main binary only
constructs 8 of them: Int, Float, Ident, Plus, Star, LParen, RParen, EOF.
The remaining 20 constructors trigger warning 37.

This stress-tests prune's ability to handle bulk constructor removal
from a large variant type without corrupting the type definition.

Build fails due to many unused constructors:

  $ dune build

Run prune to remove unused constructors:

  $ prune clean . --force
  Analyzing 1 .mli file
  
  
    Iteration 1:
    ✓ No unused code found

Verify build succeeds:

  $ dune build

  $ dune exec ./bin/main.exe
  42 (op=false, prec=0)
  + (op=true, prec=3)
  x (op=false, prec=0)
  * (op=true, prec=4)
  ( (op=false, prec=0)
  3.14 (op=false, prec=0)
  ) (op=false, prec=0)
  <EOF> (op=false, prec=0)

Show remaining constructors:

  $ grep "^\s*|" lib/token.mli | wc -l
        28
