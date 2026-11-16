# :sparkles: Spark RSS

Application to allow article & news reading an RSS feed on a Kindle (8th gen)
Functionality is based on feature in Calibre: but want to give it a go myself.

## Features
### Minimum Features:
* Track multiple RSS feeds (news aggregater sites + blogs)
* Pull down articles & news aggregater comment threads
* Render the content into a PDF/MOBI sized and formatted for the device
* Email the rendered document to the kindle device

### Tasks:
* Proof of concept the entire chain to confirm the file formats & idea works
* Parse hacker news rss feed for the article & comment thread info.
* Proof of concept rendering of articles as images in some kind of web page viewer to see if that's viable. Will decrease dev resources massively if render can be one-size-fits-all.
* Proof of concept comment thread renderer specifically designed for hacker news.
* Create simple epub / mobi output file.
* Send an email with some file.

### Feature Ideas:
* TODO

## Quickstart

### Toolchain

Install OCaml and opam 2.6 or later, plus the native development headers for
libcurl, OpenSSL, and zlib. For example, on Fedora:

```sh
sudo dnf install gcc make pkgconf-pkg-config libcurl-devel openssl-devel zlib-ng-compat-devel
```

Create a project-local OCaml switch and install the dependencies. The WebDriver
packages are hosted in a separate Git repository, so pin that source before
installing the project:

```sh
opam switch create . 5.2.1
eval "$(opam env)"
opam pin add -y webdriver_cohttp-lwt-unix git+https://github.com/art-w/ocaml-webdriver.git
opam install . --deps-only -y
```

#### Host notes (this machine)

The libcurl headers used by this host are installed user-locally in
`~/.local/ocaml-deps/usr` (no `libcurl-devel` RPM). They are not on the
default pkg-config search path, so `opam install ezcurl` (which builds the
`curl` bindings) fails with *"Package libcurl was not found in the pkg-config
search path"* unless the prefix is exported first:

```sh
export PKG_CONFIG_PATH="$HOME/.local/ocaml-deps/usr/lib64/pkgconfig:$PKG_CONFIG_PATH"
```

Add that line to `~/.bashrc` before creating or repairing the switch. For
EPUB validation, EPUBCheck is installed at `~/opt/epubcheck/epubcheck.jar`
(see [EPUB validation](#epub-validation)); geckodriver lives in
`~/.local/bin` (see [reader mode extraction](#firefox-reader-mode-extraction-recommended)).

Build and run from the activated switch. Pass one or more RSS feed URLs; the
CLI renders each linked article with Firefox reader mode (via a running
WebDriver server) when available and plain HTTP otherwise, then writes an
EPUB. `--jobs` controls how many articles are processed at once (default: 4).

```sh
make build
dune exec sparks_rss -- --output digest.epub --jobs 4 FEED_URL [FEED_URL ...]
```

### Firefox reader mode extraction (recommended)

Article extraction is driven by the Firefox WebDriver
(`lib/webdriver.ml`): the browser loads the article page and the vendored
[@mozilla/readability](https://github.com/mozilla/readability) engine — the
same engine Firefox reader mode uses — parses it into a clean article
document. Note the WebDriver protocol forbids navigating directly to
`about:reader` URLs, so the engine is executed inside the loaded page
instead; the extraction quality is the same as reader mode.

Host setup (Fedora):

```sh
# 1. Firefox (already installed on most Fedora images)
sudo dnf install firefox

# 2. geckodriver 0.36+; no root needed if you install it into ~/.local/bin
mkdir -p ~/.local/bin
curl -fsSL -o /tmp/geckodriver.tar.gz \
  https://github.com/mozilla/geckodriver/releases/download/v0.37.1/geckodriver-v0.37.1-linux64.tar.gz
tar xzf /tmp/geckodriver.tar.gz -C ~/.local/bin geckodriver
geckodriver --version

# 3. Start the driver before building an EPUB (default port 4444)
geckodriver --port 4444 &
```

`~/.local/bin` is on `PATH` by default on Fedora. If geckodriver is not
reachable, the CLI prints a warning per article and falls back to plain HTTP
extraction, so nothing fails outright. Use `-w PORT` to select another port.
geckodriver supports a single session at a time; the CLI serialises the
webdriver fetches internally.

#### Updating the vendored readability engine

`vendor/readability/Readability.js` is embedded into the binary at build
time. Refresh it with:

```sh
make update-readability            # newest upstream release
make update-readability TAG=0.6.0  # a specific release
```

See `vendor/readability/README.md` for details and licensing.

### EPUB validation

The integration test runs EPUBCheck when it is installed and skips otherwise.
On Ubuntu, install the packaged validator with `sudo apt install epubcheck`.
EPUBCheck is not in the enabled Fedora repositories on this machine; use the
[official EPUBCheck distribution](https://w3c.github.io/epubcheck/docs/installation/)
and set `EPUBCHECK_JAR` to its `epubcheck.jar` path (Java is required). On
this host the distribution is installed at `~/opt/epubcheck/epubcheck.jar`:

```sh
EPUBCHECK_JAR=~/opt/epubcheck/epubcheck.jar dune runtest
```

Run the ordinary test suite with:

```sh
dune runtest
```

Force the EPUBCheck integration test to run directly with:

```sh
make epubcheck
```
