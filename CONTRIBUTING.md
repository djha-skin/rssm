# Contributing to RSS Manager (rssm)

This document is for human and AI developers working on this project.

## Code Style and Conventions

- **Line Length**: No files—Lisp, Markdown, or Roswell scripts—should
  exceed **80 characters** per line.
- **Trailing Whitespace**: Stick to this rule. Please do not commit files with
  trailing whitespace in them.
- **ASDF System**: Use the reverse-domain ASDF package name
  (`com.djhaskin.rssm`).
- **Dependencies**: Managed via **OCICL**.
- **CLI Framework**: Use my **CLIFF** library for argument parsing and
  configuration handling.

## Component Definitions

- **Folders**: This tool supports exactly **one level** of folders.
  Nesting folders is not supported.
- **Newsboat Integration**: In Newsboat, folders are represented by
  virtual feeds. These are created using specific tags and queries.

## REPL interaction

The Lisp instance should be started using `ros run` in the designated
REPL pane of the tmux session.

Specific workflow details for AI agents are located in `AGENTS.md`.

## Building the Program

We use Roswell for building self-contained executables.

1. `ros init rssm`
2. Modifying the generated `rssm.ros` script to load the ASDF system
   and call the main entry point.
3. `ros build rssm.ros`

Follow the style of existing projects like `cliff`, `nrdl`, or `calc`
when structuring scripts.

## Tooling

This section describes the libraries and build tools used in `rssm`.
Several of them take an unusual approach to their domain and will
surprise contributors who are not already familiar with them.

### Roswell

[Roswell](https://github.com/roswell/roswell) (`ros`) is the Common
Lisp implementation manager and script runner used for this project.

**Important**: Always invoke `ros` with the `+Q` flag to disable
Quicklisp. We do not use Quicklisp. Omitting `+Q` may cause Quicklisp
to interfere with OCICL-managed dependencies.

```
ros +Q run          # Start a REPL without Quicklisp
ros +Q rssm.ros     # Run the script without Quicklisp
```

The `rssm.ros` script (generated via `ros init rssm` and then edited)
is the entry point for building the binary. It loads the ASDF system
and delegates to `com.djhaskin.rssm:main`. Note that the shebang line
in `rssm.ros` already passes `+Q`:

```lisp
exec ros +Q -- $0 "$@"
```

**Building the binary**:

```
ros build rssm.ros
```

This produces a self-contained `rssm` executable. Roswell is always
run against the latest version of SBCL in day-to-day development.

### OCICL

[OCICL](https://github.com/ocicl/ocicl) is the dependency manager for
this project. It is a modern alternative to Quicklisp that distributes
ASDF systems as OCI-compliant container image artifacts.

**We do not use Quicklisp.** Do not add Quicklisp-based loading to
any file in this project.

**How OCICL works**:

- `ocicl.csv` — tracks the exact pinned versions of all dependencies.
  This file is committed to source control.
- `ocicl/` — the directory where downloaded library source trees live.
  This directory is **not** committed to source control.

When you load an ASDF system, the `ocicl-runtime` (loaded via
`~/.roswell/init.lisp` or `~/.sbclrc`) intercepts missing-system
errors and downloads the correct version from the OCI registry.

**Installing dependencies** (re-downloads all entries in `ocicl.csv`):

```
ocicl install
```

**Adding a new dependency**:

```
ocicl install <system-name>
```

This downloads the latest version and adds it to `ocicl.csv`.

**Updating all dependencies to latest versions**:

```
ocicl latest
```

#### Troubleshooting: Weird Compile Errors

If you encounter inexplicable compile errors or stale FASL issues,
the most reliable fix is to delete the `ocicl/` directory and let
OCICL re-download everything from `ocicl.csv`:

```
rm -rf ocicl/
ocicl install
```

In rare cases where `ocicl.csv` itself is suspected to be corrupt or
out of sync (e.g., after a failed partial update), delete both:

```
rm -rf ocicl/ ocicl.csv
ocicl install <each-dependency>
```

Then re-add each dependency listed in `com.djhaskin.rssm.asd` by
name. This has happened before and is the known recovery procedure.

### CLIFF

[CLIFF](https://djha-skin.github.io/cliff/) (Command Line Interface
Functional Framework) is the CLI library used by `rssm`. It is
authored by the same developer as `rssm` (`com.djhaskin.cliff`).

CLIFF provides the `execute-program` function, which drives the
entire CLI lifecycle:

1. Reads configuration from files, environment variables, and
   command-line arguments — in that priority order (CLI wins).
   This layered lookup is called the **Options Tower**.
2. Determines which action function to call based on the subcommand.
3. Calls the action function with the resolved options map.
4. Handles output and error reporting uniformly.

**Key API**:

```lisp
(com.djhaskin.cliff:execute-program
  "rssm"           ; program name (used in help text)
  :actions         ; plist of subcommand name -> function
  '("export" #'export-feeds
    "import" #'import-feeds)
  :setup           ; optional function run before action dispatch
  #'setup-fn)
```

Action functions receive a single argument: a hash-table of resolved
options. They should return a hash-table with at least a `:status`
key (`:ok` or `:fail`) and optionally a `:result` key.

CLIFF also provides helpers such as:
- `ensure-option-exists` — signal a clear error if a required option
  is missing.
- `data-slurp` — read structured data (NRDL/JSON/EDN) from stdin or
  a file option.
- `find-file` — locate a config file by searching standard paths.

Refer to the [CLIFF docs](https://djha-skin.github.io/cliff/) and
the existing `src/main.lisp` for usage patterns.

### Plump

[Plump](https://shinmera.github.io/parachute/) is the XML/HTML parser
used in `src/opml.lisp` for reading and writing OPML files.

Plump is lenient: it handles malformed markup gracefully, which is
useful when dealing with real-world OPML files exported from various
RSS readers.

**Basic usage pattern** (as used in `src/opml.lisp`):

```lisp
;; Parse an OPML string or stream into a DOM root node
(let ((doc (plump:parse opml-string)))
  ;; Traverse elements by tag name
  (plump:get-elements-by-tag-name doc "outline"))
```

Key functions:
- `plump:parse` — parses a string, pathname, or stream into a DOM.
- `plump:get-elements-by-tag-name` — find all elements by tag.
- `plump:attribute` / `(setf plump:attribute)` — read/write
  element attributes.
- `plump:serialize` — render the DOM back to a string or stream.

For strict XML parsing (disabling HTML-specific tag behaviour, as
needed for OPML), bind `plump:*tag-dispatchers*` to
`plump:*xml-tags*` during parsing:

```lisp
(let ((plump:*tag-dispatchers* plump:*xml-tags*))
  (plump:parse opml-string))
```

### Parachute

[Parachute](https://shinmera.github.io/parachute/) is the testing
framework used in the `tests/` directory (the
`com.djhaskin.rssm/tests` ASDF subsystem).

Tests are defined with `parachute:define-test` and assertions use
macros like `parachute:is`, `parachute:true`, `parachute:false`,
and `parachute:fail`.

**Defining a test**:

```lisp
(parachute:define-test my-feature
  (parachute:is equal "expected" (my-function "input"))
  (parachute:true (some-predicate result)))
```

**Running tests** from the REPL:

```lisp
;; Run a single named test
(parachute:test 'com.djhaskin.rssm/tests)

;; Run via ASDF (preferred)
(asdf:test-system "com.djhaskin.rssm")
```

**Running tests** from the shell (without a running REPL):

```
ros +Q -- --eval '(asdf:test-system "com.djhaskin.rssm")' \
          --eval '(uiop:quit)'
```

The test system is defined as the `com.djhaskin.rssm/tests` subsystem
in `com.djhaskin.rssm.asd`. Its `:perform` clause calls
`(parachute:test :com.djhaskin.rssm/tests)` automatically when
`asdf:test-system` is invoked.
