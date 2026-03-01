# Contributing to RSS Manager (rssm)

This document is for human and AI developers working on this project.

## Development Workflow

This project adheres to **Test-Driven Development (TDD)**:

1. **Documentation First**: Describe the feature in `README.md`.
2. **Tests Second**: Implement tests for the feature in `tests/`.
3. **Implementation Last**: Add the feature's logic in `src/`.

## Code Style and Conventions

- **Line Length**: No files—Lisp, Markdown, or Roswell scripts—should
  exceed **80 characters** per line. Stick to this rule.
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
