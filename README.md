# RSS Manager (rssm)

Do you love terminal RSS readers like Newsboat but hate managing their
`urls` file by hand? Tired of having your feeds trapped in one format
or another?

Then RSSM is for you!

RSSM is a personal tool I'm building originally for myself to keep
track of my RSS feed ecosystem. It works across three primary systems:

- **Newsboat**: Terminal-based RSS reader.
- **RSSSavvy**: Web-based RSS reader.
- **OPML**: The universal standard for feed lists.

It manages your feeds and folders (one level deep) and handles the
dirty work of syncing virtual feeds in Newsboat using queries and
tags. No more manual syncing when you want to trial a new tool or
cleanup your collection.

## Get it

RSSM is built using Common Lisp and [ocicl](https://github.com/ocicl/ocicl).

```bash
ros build rssm.ros
./rssm --version
```

## Features

- Parse and manipulate Newsboat `urls` files.
- Export/Import RSSSavvy JSON configurations.
- Standard OPML support.
- Convert between formats with the `convert` subcommand:
  ```bash
  # Convert Newsboat to OPML
  rssm convert --source-format newsboat --dest-format opml \
               --input ~/.newsboat/urls --output feeds.opml

  # Short flags are also supported
  rssm convert -s json -d newsboat -i feeds.json -o ~/.newsboat/urls
  ```
  Supported formats: `newsboat`, `json` (RSSSavvy), `opml`.
- CLI interface powered by my [CLIFF](https://github.com/djha-skin/cliff)
  library.
- Automated feed discovery and cleanup.

### Conversions

The `convert` command transforms feeds through a shared internal model.

Supported formats for both source and destination:

1. `newsboat`: Newsboat `urls` format. The first tag on a feed line is
   treated as the folder name.
2. `json`: RSSSavvy subscription JSON.
3. `opml`: Outline Processor Markup Language.

Folder mapping rules (single-level only):

- Newsboat tags -> one folder (first tag only)
- RSSSavvy groups -> folder title, via `"RS <url>"` filters
- OPML nested outline -> parent outline title as folder

Examples:

```bash
# OPML to RSSSavvy JSON
rssm convert -s opml -d json -i feeds.opml -o feeds.json

# RSSSavvy JSON to Newsboat
rssm convert -s json -d newsboat -i feeds.json -o ~/.newsboat/urls
```

## Documentation

For information on contributing, see [CONTRIBUTING.md](CONTRIBUTING.md).
For LLM agents working on this project, see [AGENTS.md](AGENTS.md).
Check out [ROADMAP.md](ROADMAP.md) to see where we're going.
