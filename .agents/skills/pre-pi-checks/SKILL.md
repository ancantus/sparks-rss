---
name: pre-pi-checks
description: Run every CI check for sparks-rss locally (build, dune runtest, dune build @fmt, opam lint) with the ocaml55 switch and confirm they all pass before pushing or opening a PR.
---

# Pre-Pi Checks

Run the same gate as `.github/workflows/ci.yml`, plus an end-to-end EPUB smoke
test, before handing work off or pushing. Every step must exit 0; a formatting
diff or lint warning is a failure, not a warning.

## Run everything

```sh
.agents/skills/pre-pi-checks/scripts/check.sh
```

The script changes to the repository root, activates the `ocaml55` switch, sets
`PKG_CONFIG_PATH` for the user-local libcurl headers, then runs each check in
order, ending with the local EPUB generation script. It stops at the first
failure and prints the failing command.

## The checks

Run them sequentially, in this order, from the repository root:

```sh
eval "$(opam env --switch=ocaml55)"
export PKG_CONFIG_PATH="$HOME/.local/ocaml-deps/usr/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"

dune build            # compile everything
dune runtest          # unit tests + EPUBCheck integration test
dune build @fmt       # ocamlformat / dune-file formatting check
opam lint sparks_rss.opam
tools/generate-sparks-rss-quick.sh   # generate a real EPUB as a smoke test
```

### What each one covers

| Check                 | Catches                                              |
| --------------------- | ---------------------------------------------------- |
| `dune build`          | Compile errors and missing dependencies              |
| `dune runtest`        | Test failures in `test/test_sparks_rss.ml` and `test/test_epubcheck.ml` |
| `dune build @fmt`     | Unformatted OCaml or `dune` files (prints a diff and exits non-zero) |
| `opam lint`           | Invalid or missing fields in `sparks_rss.opam`        |
| `generate-sparks-rss-quick.sh` | End-to-end CLI failure; the script also checks that `quick-test.epub` was created and is non-empty |

### Tests and EPUBCheck

`dune runtest` runs both test executables. `test_epubcheck` validates a
generated EPUB when a validator is available and prints
`EPUBCheck not installed; skipping integration check.` otherwise.

To include EPUB validation locally, point at the installed jar before running:

```sh
EPUBCHECK_JAR=~/opt/epubcheck/epubcheck.jar .agents/skills/pre-pi-checks/scripts/check.sh
```

## Fixing failures

- **Formatting:** `dune build @fmt` does not rewrite files. Apply the fix with
  `dune build @fmt --auto-promote`, review the changed files, then re-run the
  check. Only auto-promote when the task includes fixing formatting.
- **Tests:** read the failing test name and assertion message from the output.
  Re-run a single executable with
  `dune exec test/test_sparks_rss.exe` while debugging.
- **Lint:** fix `sparks_rss.opam` or its generated fields in `dune-project`
  (`opam lint` reads the generated `.opam` file).
- **Build errors:** if a package is missing, install it into the switch with
  `opam install . --deps-only --with-test --with-dev-setup -y`.

## Notes

- `dune build` regenerates `sparks_rss.opam` from `dune-project`
  (`generate_opam_files`). If the two disagree, the build leaves the `.opam`
  file modified; keep that change when dependencies changed, or revert it when
  it is unrelated to the task. `opam lint` checks the regenerated file.
- Never run these `dune` commands in parallel in the same checkout: they share
  `_build` and its RPC server, and one can fail with
  `Build requests require a watch-mode server`.
- Report the exact failing command and the relevant output. Do not claim the
  checks pass unless every command exited 0.
- For just the build, use the `ocaml55-build` skill.
