#!/bin/sh
# Full generation script to generate an EPUB with articles from multiple RSS feeds.
# Feeds: Hacker News and Lobst.re (no article limit).
#
# Usage: tools/generate-sparks-rss-full.sh

set -eu

# Ensure we're using the correct directory structure
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Switch configuration
OCCAML_SWITCH="ocaml55"

# Activate ocaml55 switch - source opam init to set up environment
eval "$(opam env --switch=$OCCAML_SWITCH)"

cd "$PROJECT_DIR"

# Define RSS feed sources as bash array
FEEDS=(
    "https://lobste.rs/rss"
    "https://news.ycombinator.com/rss"
)

# Build the command line with all feeds
FEED_ARGS=""
for feed in "${FEEDS[@]}"; do
    FEED_ARGS="$FEED_ARGS $feed"
done

# Generate EPUB from all feeds (no article limit specified means default behavior)
dune exec sparks_rss \
    -- --output full-generation.epub --jobs 8 $FEED_ARGS || true

echo "Generated EPUB: full-generation.epub"
