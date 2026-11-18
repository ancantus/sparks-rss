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

Create the `ocaml55` switch once, or select it if it already exists. Then
activate it in each new shell. The WebDriver OCaml packages are hosted in a
separate Git repository, so pin both packages from that repository before
installing the project dependencies:

```sh
opam switch create ocaml55 5.5.0  # skip if this switch already exists
opam switch set ocaml55          # select it for this shell/session
eval "$(opam env --switch=ocaml55)"
```

If you use the user-local libcurl headers described below, export their pkg-config
path before installing dependencies. Otherwise, the system development packages
installed above provide the headers automatically.

```sh
export PKG_CONFIG_PATH="$HOME/.local/ocaml-deps/usr/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"
```

Add that line to `~/.bashrc` if you want it in each new shell. The libcurl
headers on this host are installed in `~/.local/ocaml-deps/usr`, rather than
through an RPM package. EPUBCheck is installed at `~/opt/epubcheck/epubcheck.jar`
(see [EPUB validation](#epub-validation)); geckodriver lives in
`~/.local/bin` (see [reader mode extraction](#firefox-reader-mode-extraction-required)).

Pin the WebDriver packages and install the project dependencies:

```sh
opam pin add -y webdriver git+https://github.com/art-w/ocaml-webdriver.git
opam pin add -y webdriver_cohttp-lwt-unix git+https://github.com/art-w/ocaml-webdriver.git
opam install . --deps-only --with-test --with-doc -y
```

Build and run from the activated switch. Pass one or more RSS feed URLs; the
CLI renders each linked article with Firefox reader mode through WebDriver,
then writes an EPUB. WebDriver and geckodriver are required. `--jobs` controls
how many articles are processed at once (default: twice the recommended domain
count). `--limit N` processes only the first N articles.

```sh
make build
dune exec sparks_rss -- --output digest.epub --jobs 4 FEED_URL [FEED_URL ...]
```

### Comment threads (Hacker News and Lobsters)

Articles whose RSS `<comments>` link points at a Hacker News item or Lobsters
story (`lobste.rs/s/<short_id>`, detected by `lib/lobsters.ml`) get a second
chapter, `Comments: <article title>`, saved immediately after the article.
Each aggregator implements the shared `Comments.SOURCE` interface, and the
renderer consumes the common flattened comment type. If a supported comments
page cannot be fetched, the article is still published and a warning is
printed.

### Firefox reader mode extraction (required)

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

`~/.local/bin` is on `PATH` by default on Fedora. If an article cannot be
extracted, the CLI writes a placeholder for that article and continues. Use
`-w PORT` to select another port.
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
