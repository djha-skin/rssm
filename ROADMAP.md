# RSSM Roadmap

This document outlines the planned features and current status of the
RSS Manager (RSSM).

## Current Status

The project is initialized with the basic structure, ASDF systems,
and build scripts using Roswell, OCICL, and CLIFF.

### Completed Work

- **`src/backend.lisp`**: Core abstract backend types and generic
  function stubs (`parse-feeds`, `render-feeds`) — stable, no changes
  needed.
- **`src/newsboat.lisp`**: Newsboat `urls` file parser and renderer —
  fully implemented and compiling cleanly. Three bugs were found and
  fixed:
  - `token-to-tag` used wrong initarg (`:custom-name` instead of
    `:title`) when constructing `newsboat-tag` instances.
  - `token-to-tag` had an out-of-bounds `aref` on bare `"!"` tokens
    (no bounds check before indexing `next-spot`).
  - `parse-feeds :newsboat` used `#'string=` (function object) as
    `:test` in `make-hash-table`; fixed to `'equal`.
- **`tests/newsboat.lisp`**: Full unit test suite written for
  `src/newsboat.lisp`. 66 assertions, all passing. Covers:
- **`src/rsssavvy.lisp`**: RSSSavvy JSON parser and renderer using NRDL.
  Fully implemented with helper functions (`filter-to-url`,
  `rsssavvy-group-to-folder`, `rsssavvy-folder-of-url`, etc.) and
  backend methods for `parse-feeds` and `render-feeds`.
- **`tests/rsssavvy.lisp`**: Full unit test suite for RSSSavvy support.
  39 assertions, all passing. Covers:
  - `read-quoted` (6 tests)
  - `render-quoted` (4 tests)
  - Round-trip `read-quoted` / `render-quoted` (2 tests)
  - `next-token` (6 tests)
  - `token-to-tag` (7 tests)
  - `concrete-feed-p` (2 tests)
  - `newsboat-to-generic` (4 tests)
  - `read-next-line` (4 tests)
  - `parse-feeds :newsboat` (6 tests)
  - `render-feeds :newsboat` (5 tests)

### Completed Work (Continued)

- **`src/opml.lisp`**: OPML import/export using Plump. Fully implemented
  with `parse-feeds :opml` and `render-feeds :opml` methods. Fixed
  Plump DOM element checks to properly handle XML header and text nodes.
- **`src/main.lisp`**: CLI via CLIFF with `convert` subcommand. Supports
  converting between Newsboat, RSSSavvy JSON, and OPML formats. Features:
  - File or string input/output
  - CLI aliases for common options (-s, -d, -i, -o)
  - Output to stdout (with `-o -`) or file
  - Proper error handling and exit codes
- **`tests/main.lisp`**: Integration tests for CLI conversion. 38 tests
  covering all format combinations and round-trip conversions.

## Features

- [x] **Newsboat Format Parsing**
  - Parse `urls` files.
  - Handle virtual feeds, queries, and tags.
  - Unit tests (66 passing).
- [x] **RSSSavvy JSON Support**
  - Import/Export functionality for RSSSavvy's JSON structure.
    Uses NRDL for JSON parsing and generation.
- [x] **OPML Support**
  - Standard OPML import/export (Plump-based).
- [ ] **Folder Management**
  - Implement single-level folder support across all formats.
- [ ] **Automated Feed Cleanup**
  - Feature to delete feeds which have not been updated in more than
    five years.
- [ ] **Heuristic Feed Discovery**
  - Take a blog URL and search for XML RSS/Atom feed URLs by guessing
    common locations (e.g., /feed, /rss, /atom.xml).
- [x] **Format Conversion**
  - Export feed lists from any of the three target formats to another.
  - Use `./rssm convert -s <format> -d <format> -i <input>`
- [x] **CLIFF Integration**
  - Fully functional CLI with configuration file support.
  - Use `./rssm help` for usage information.


---
