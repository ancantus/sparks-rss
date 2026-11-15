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

Build and run from the activated switch. Pass one or more RSS feed URLs; the
CLI downloads linked article pages over HTTP, converts their text and images,
and writes an EPUB. Pages that need JavaScript to render content may produce
only their RSS summary.

```sh
make build
dune exec sparks_rss -- -o digest.epub https://example.com/feed.xml
```

The Firefox WebDriver module remains available for future extraction work, but
the CLI does not require a browser or WebDriver server.
