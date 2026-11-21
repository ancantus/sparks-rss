#!/usr/bin/env bash
# Full local CI gate for sparks-rss.
#
# Runs, in order:
#   1. dune build
#   2. dune runtest
#   3. dune build @fmt            (fails on formatting diffs)
#   4. opam lint sparks_rss.opam
#   5. tools/generate-sparks-rss-quick.sh, then verifies quick-test.epub
#      exists and validates it with EPUBCheck when a validator is available.
#
# Dune commands run sequentially because they share _build and its RPC server;
# parallel invocations can fail with "Build requests require a watch-mode
# server".
#
# The script activates the ocaml55 switch and sets PKG_CONFIG_PATH for the
# user-local libcurl headers in ~/.local/ocaml-deps.
set -euo pipefail

SWITCH="${OCAML_SWITCH:-ocaml55}"
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$(git rev-parse --show-toplevel)"

if ! opam switch list --short | grep -qx "$SWITCH"; then
  printf "opam switch '%s' not found. Ask the user to set it up.\n" "$SWITCH" >&2
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

printf '\n==> tools/generate-sparks-rss-quick.sh\n'
rm -f quick-test.epub
tools/generate-sparks-rss-quick.sh || failed "tools/generate-sparks-rss-quick.sh"
if [ ! -s quick-test.epub ]; then
  failed "tools/generate-sparks-rss-quick.sh did not create quick-test.epub"
fi

# EPUBCheck is optional: use $EPUBCHECK_JAR, then the jar installed on this
# host, then an `epubcheck` on PATH. Skip when none is available.
EPUBCHECK_JAR="${EPUBCHECK_JAR:-$HOME/opt/epubcheck/epubcheck.jar}"
if [ -f "$EPUBCHECK_JAR" ]; then
  printf '\n==> java -jar %s quick-test.epub\n' "$EPUBCHECK_JAR"
  java -jar "$EPUBCHECK_JAR" quick-test.epub ||
    failed "EPUBCheck rejected quick-test.epub"
elif command -v epubcheck >/dev/null 2>&1; then
  printf '\n==> epubcheck quick-test.epub\n'
  epubcheck quick-test.epub || failed "EPUBCheck rejected quick-test.epub"
else
  printf '\nEPUBCheck not found; skipping EPUB validation.\n'
fi

printf '\nAll pre-pi checks passed.\n'
