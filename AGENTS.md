# Agent Workflow Notes

This document is exclusively for LLM contributors working on RSSM.

> **Important**: Please make sure to read `CONTRIBUTING.md` before
> starting any work on this project. It contains essential information
> about tooling, code style, and common workflows that apply to all
> contributors, including AI agents.

## Project Overview

RSS Manager (rssm) is a command-line tool for managing RSS feeds
across three different systems:

- **Newsboat**: Terminal RSS reader using `urls` file format.
  - Folders are implemented as **virtual feeds** created via queries
    and tags (e.g., tagging feeds "News" and creating a query feed).
- **RSSSavvy**: Web-based RSS reader with JSON export/import.
- **OPML**: Standard XML format for RSS feed lists.

## Core Rules

- **Folder Management**: Only **one level of folders** is supported.
  Folder nesting is strictly **not supported**.
- **Line Length**: All `.lisp`, `.ros`, and `.md` files must adhere to
  a strict **80-character** limit.

## Design Decisions

- **Package naming**: Reverse-domain ASDF package name
  (`com.djhaskin.rssm`).
- **Dependencies**: OCICL (not Quicklisp). Use `com.djhaskin.cliff` for
  CLI parsing and configuration.
- **Testing**: Parachute library for Test-Driven Development (TDD).

## Development Workflow (TDD)

1. **Documentation First**: Update `README.md` with feature specs.
2. **Tests Second**: Write tests in `tests/`.
3. **Implementation Last**: Add code in `src/`.

## REPL and environment

The development environment is inside a **tmux** session with three
panes:

- **Pane 0**: Reserved for the Lisp REPL. Invoke with `ros run`.
- **Pane 1**: Goose CLI (this session).
- **Pane 2**: Manual user commands.

### Interaction Procedure

1. **Read First**: Use `tmux capture-pane -t 0 -p` to see the current
   REPL status before acting.
2. **Start REPL**: If not running, send `ros run` to pane 0.
3. **Eval Lisp**: Send expressions to pane 0 using `tmux send-keys`.
4. **Exit REPL**: Use `(ros:quit)` or `(sb-ext:exit)`.

## Building the Project

We use Roswell to build self-contained executables.

1. **Initialize script**: `ros init rssm` (generates `rssm.ros`).
2. **Setup script**: Edit `rssm.ros` to load the system and call the
   `main` function from `com.djhaskin.rssm`. Refer to `cliff` or `nrdl`
   repos for exact patterns.
3. **Build**: Run `ros build rssm.ros` to produce the `rssm` binary.

## Project Vision & Roadmap

Features to implement (see `ROADMAP.md`):
- Deleting feeds inactive for >5 years.
- Guessing RSS/Atom URLs from a blog URL (searching common paths).
- Exporting feed lists between the three target formats.
