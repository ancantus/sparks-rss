---
name: pre-pi-checks
description: Run every CI check for sparks-rss locally (build, tests, formatting, opam lint, EPUB smoke test) with the ocaml55 switch and confirm they all pass before pushing or opening a PR.
---

# Pre-Pi Checks

Run the full local gate:

```sh
.agents/skills/pre-pi-checks/scripts/check.sh
```

It runs `dune build`, `dune runtest`, `dune build @fmt`, `opam lint
sparks_rss.opam`, then `tools/generate-sparks-rss-quick.sh` and verifies the
generated EPUB, validating it with EPUBCheck when available. It stops at the
first failure and prints the failing command. See the script comments for
details.

Fix formatting with `dune build @fmt --auto-promote`, then re-run. Only report
success when every step exits 0.
