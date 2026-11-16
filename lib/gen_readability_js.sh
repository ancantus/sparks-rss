#!/bin/sh
# Generate lib/readability_js.ml embedding the vendored Readability.js.
# Usage: sh gen_readability_js.sh path/to/Readability.js
# The output is a dune-managed build artifact; edit the vendored file instead.
set -eu

src="$1"
delim="__readability_string__"

if [ ! -s "$src" ]; then
  echo "gen_readability_js.sh: missing or empty input: $src" >&2
  exit 1
fi

if grep -q "|$delim|" "$src"; then
  echo "gen_readability_js.sh: input contains the OCaml string delimiter" >&2
  exit 1
fi

{
  printf '(* GENERATED from vendor/readability/Readability.js -- edit the\n'
  printf '   vendored file and rebuild instead of this file. See\n'
  printf '   vendor/readability/README.md *)\n'
  printf 'let readability_js = {'
  printf '%s' "$delim"
  printf '|'
  cat "$src"
  printf '|'
  printf '%s' "$delim"
  printf '}\n'
}
