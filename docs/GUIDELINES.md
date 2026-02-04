# Coding guidelines

## 1  Overall philosophy

* Strive for **small, orthogonal modules** that can be composed freely.
* Depend only on the standard library (and occasionally on other “micro-libs”, e.g. `Fmt`, `Rresult`).
* Preserve **purity** and determinism in the core; confine effects to thin I/O layers.
* Offer **total functions** whenever feasible and expose *explicit* failure via `'a result`.
* Maintain **API stability**: once an identifier is public, avoid breaking changes; add instead of mutate.

---

## 2  Project layout

```
my_lib/
├─ dune-project
├─ README.md        – high-level overview & minimal example
├─ CHANGES.md       – human-written change-log
├─ lib/             – library source code (alternative to src/)
│  ├─ my_lib.mli    – canonical public interface
│  └─ my_lib.ml     – implementation
├─ bin/             – executable entry points
└─ test/            – Alcotest or inline-tests
```

*Put the public interface in a single `.mli` whenever practical.  Split only when the conceptual surface really warrants distinct compilation units. Using `lib/` and `bin/` directories instead of `src/` is acceptable for projects with both libraries and executables.*

---

## 3  Modules and sub-modules

| Purpose          | Idiom                                                                          |
| ---------------- | ------------------------------------------------------------------------------ |
| Canonical type   | `type t` (abstract)                                                            |
| Pretty printer   | `val pp : t Fmt.t`                                                             |
| Conversions      | `val to_string : t -> string`<br>`val of_string : string -> (t, error) result` (when meaningful) |
| Equality & order | `val equal : t -> t -> bool`<br>`val compare : t -> t -> int` (when meaningful) |
| Constructors     | `val v : ... -> (t, error) result` (or pure `t` if infallible)                 |
| Low-level view   | `module Unsafe : sig … end` (optional)                                         |

*Keep the root module *flat*; introduce nested modules only for clearly separable concerns (e.g. `My_lib.Path`, `My_lib.Map`).*

---

## 4  Naming conventions

* **Modules / files** – lower-case, underscore-separated file names (`my_lib.ml`), capitalised module names (`My_lib`).
* **Values** – short but descriptive (`pp`, `v`, `find`, `with_…`).
* **Labels** – prefer them only when they disambiguate (`~dir`, `~mode`); avoid gratuitous labels on simple data.
* **Boolean arguments** – almost never positional; wrap in a variant or use a labelled argument (`?dry_run:bool`).
* **Infix operators** – expose only if widespread (`>|=`) or central to the library (`Fpath.( / )`).  Put them in a dedicated sub-module `Op`.

---

## 5  Types

* Keep *representation hidden* (`type t`) and provide construction/destruction helpers.
* Introduce **phantom parameters** to encode invariants if it avoids run-time checks.
* Use **private types** when callers may inspect but not forge values (`type t = private string`).
* For **enumerations**, use a closed variant; supply `val all : t list` and `val to_string`.
* Reserve **exceptions** for programming errors (`Invalid_argument`, assertion failures).  Operational errors travel in the `'error` part of `('a, error) result`.
* **Formatting**: Use `Fmt` consistently for all output. Never mix `Printf` and `Fmt` - use `Fmt.pr` for user-facing messages, keep `Printf.printf` only for TTY progress display.
* **Regular expressions**: Use the Re DSL instead of Re.Perl. Prefer `Re.(compile (seq [...]))` over `Re.Perl.compile_pat`.

---

## 6  Error handling pattern (`Rresult`)

### Base Error Types

```ocaml
type error = [ `Msg of string | `Build_error of context ]
val pp_error : error Fmt.t
val v : ... -> (t, error) result
```

### Error Helper Functions Pattern

Start implementation files with error helper functions (`err_*`) for consistent error messages:

```ocaml
(* Error helper functions *)
let err fmt = Fmt.kstr (fun e -> Error (`Msg e)) fmt

let err_file_read file msg = err "Failed to read %s: %s" file msg
let err_file_write file msg = err "Failed to write %s: %s" file msg
```

Use `%a` with pretty printers for complex formatting:
```ocaml
let pp_build_error ppf ctx = Fmt.pf ppf "%s" ctx.output
let err_build_failed ctx = err "Build failed:@.%a" pp_build_error ctx
```

For structured errors with context:
```ocaml
let err_build_error ctx = Error (`Build_error ctx)
```

### Library vs Main Separation

**Critical Rule**: Library code never calls `exit` directly - only returns errors for main.ml to handle.

```ocaml
(* In library code - ALWAYS return structured errors *)
let handle_build_failure ctx =
  (* Display specific context *)
  Fmt.pr "Loop detected - stopping to prevent infinite iterations.@.";
  (* Return error for main.ml to handle *)
  err_build_error ctx

(* In main.ml - handle all exit logic *)
match analyze mode root_dir files with
| Ok result -> result
| Error (`Build_error ctx) -> 
    System.display_build_failure_and_exit ctx  (* Exits with build's code *)
| Error e -> 
    Format.eprintf "Error: %a@." pp_error e; 
    exit 1  (* Generic error code *)
```

### Error Display Consistency

Use unified display functions for consistent UX:
```ocaml
(* In system.ml *)
let display_build_failure_and_exit ctx =
  let all_warnings = (* parse build output *) in
  Fmt.pr "%a with %d %s - full output:@."
    Fmt.(styled (`Fg `Red) string) "Build failed"
    (List.length all_warnings)
    (if List.length all_warnings = 1 then "error" else "errors");
  Fmt.pr "%a@." pp_build_output ctx;
  let exit_code = get_build_exit_code ctx in
  exit exit_code
```

### Guidelines

* Accept a caller-provided buffer (`Buffer.t`) or formatter when the operation might produce extensive diagnostics.
* Re-use `Fmt.failwith`/`Fmt.invalid_arg` for internal invariants; never expose raw `Printexc` traces.
* **Never mix exit logic in library code** - always return structured errors that main.ml can handle appropriately.

---

## 7  Public API surface

1. **Minimal** yet **composable**.  Do not wrap the entire Unix API—wrap just enough to remove boilerplate.
2. Expose **first-class values** rather than functors where a closure suffices.
3. Keep *effectful* helpers separate (`My_lib_unix`, `My_lib_lwt`) to avoid dragging unwanted dependencies.

---

## 8  Interface documentation (`.mli`, `.mld`)

*Document **every** public item in the `.mli`.  Place docstrings **after** the item unless it spans multiple lines, using code-first voice.*

### 8.1  Structure and style

```
(** {1 Overview}

    One concise paragraph explaining the abstraction.  Link to the README
    for a tutorial.

    {2 Types}

    {3 Constructors}

    {4 Accessors}

    {5 Derived combinators}

    {6 Pretty-printing}

*)
```

* Use **section headings** (`{1 …}`, `{2 …}`) to group logically related functions.
* Provide **usage examples** in `[{[ … ]}]` blocks that compile under `odoc-latency-level:normal`.
* Annotate complexity (`@since`, `@deprecated`, `@raise`, `@see`) rigorously.
* Keep comments declarative: *what* and *guarantees*, never implementation detail.

---

## 9  Testing & auxiliary artefacts

* Unit tests with **Alcotest** (`test/`) mirroring the public API sections.
* **Cram tests**: Use directory-based cram tests (`test/name.t/`) instead of inline `cat EOF` commands for complex file creation. This is cleaner and easier to maintain.
* Provide a `tool/` directory of executable samples that double as integration tests.
* Ship an `odig` metadata file so `odig odoc` builds HTML docs out-of-the-box.

---

## 10  Versioning & release process

* Tag releases with `vN.N.N`; follow semantic versioning.
* Maintain `CHANGES.md` with *user-visible* entries only.
* Publish through `topkg` or Dune’s built-in release workflow; push docs to `gh-pages` via `odoc`.

---

## 11  Style Checklist

| Step                                                        | Done |
| ----------------------------------------------------------- | ---- |
| `src/<lib>.mli` written first, fully documented             | ☐    |
| All errors returned as `'a result` with `Rresult` helpers   | ☐    |
| `pp`, `equal`, `compare`, `hash` supplied where meaningful  | ☐    |
| No hidden global side-effects; pure core separated          | ☐    |
| Example snippets compile under `dune build @doc`            | ☐    |
| Dependency list reviewed: stdlib ± {Fmt, Rresult, Alcotest} | ☐    |
| `test/` provides Alcotest suites mirroring API sections     | ☐    |

Tick every box before publishing.
