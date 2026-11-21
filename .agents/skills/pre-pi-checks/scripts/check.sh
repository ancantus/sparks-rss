#!/usr/bin/env bash
# Run the full CI gate locally: build, tests, formatting, opam lint.
set -euo pipefail

SWITCH="${OCAML_SWITCH:-ocaml55}"
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$(git rev-parse --show-toplevel)"

if ! opam switch list --short | grep -qx "$SWITCH"; then
  printf "opam switch '%s' not found.\nCreate it with: opam switch create %s 5.5.0\n" \
    "$SWITCH" "$SWITCH" >&2
  exit 1
fi

eval "$(opam env --switch="$SWITCH" --set-switch)"
export PKG_CONFIG_PATH="$HOME/.local/ocaml-deps/usr/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"

failed() {
  printf "\nFAILED: %s\n" "$1" >&2
  exit 1
}

printf '==> dune build\n'
dune build || failed "dune build"

printf '\n==> dune runtest\n'
dune runtest || failed "dune runtest"

printf '\n==> dune build @fmt\n'
dune build @fmt || failed "dune build @fmt (run 'dune build @fmt --auto-promote' to fix)"

printf '\n==> opam lint sparks_rss.opam\n'
opam lint sparks_rss.opam || failed "opam lint sparks_rss.opam"

printf '\nAll pre-pi checks passed.\n'
