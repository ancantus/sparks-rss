# Vendored dependency: @mozilla/readability

`Readability.js` is the article-extraction engine that Firefox reader mode
uses internally. We run it inside the browser (via the WebDriver `execute`
command) to format arbitrary sites into EPUB-friendly article documents.

* Upstream: https://github.com/mozilla/readability
* Pinned version: see `pinned-version` (latest verified: 0.6.0)
* License: Apache License 2.0 (https://github.com/mozilla/readability/blob/main/LICENSE)

## Updating

Run from the repository root:

```sh
make update-readability            # update to the newest upstream tag
make update-readability TAG=0.6.0  # update to a specific tag
```

The script rewrites `Readability.js` and `pinned-version`, and fails loudly if
the file changes in a way the build can no longer embed. After updating, run
`make build` and `dune runtest` to confirm the new extraction still works.
