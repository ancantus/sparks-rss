#!/usr/bin/env bash
# Build sparks-rss with the ocaml55 opam switch.
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

exec dune build "$@"
