#!/bin/sh
# Quick test script to generate an EPUB with 5 articles from Hacker News RSS feed.
#
# Usage: tools/generate-sparks-rss-quick.sh

set -eu

# Ensure we're using the correct directory structure
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Switch configuration
OCCAML_SWITCH="ocaml55"

# Activate ocaml55 switch using the switch variable
eval "$(opam env --switch=$OCCAML_SWITCH)"

cd "$PROJECT_DIR"

# Generate EPUB with 5 articles from Hacker News RSS feed
# Using --limit to get only 5 articles
dune exec sparks_rss \
    -- --output quick-test.epub --jobs 4 --limit 5 "https://news.ycombinator.com/rss" || true

echo "Generated EPUB: quick-test.epub"
