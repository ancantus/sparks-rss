---
name: ocaml55-build
description: Build sparks-rss with the ocaml55 opam switch, including the switch activation and libcurl pkg-config setup this host needs. Use whenever building, compiling, or running dune targets in this repository.
---

# OCaml 5.5 Build

This project builds with OCaml 5.5 in the `ocaml55` opam switch. The switch is
not active by default, so every shell must activate it before running `dune`.

## Quick build

```sh
eval "$(opam env --switch=ocaml55)"
export PKG_CONFIG_PATH="$HOME/.local/ocaml-deps/usr/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"
dune build
```

Or run the bundled script, which does the activation and the build:

```sh
.agents/skills/ocaml55-build/scripts/build.sh
```

The script changes to the repository root first, so it works from any
subdirectory, and passes any arguments through to `dune`, for example
`scripts/build.sh @doc`.

## Why each step matters

1. **`eval "$(opam env --switch=ocaml55)"`** puts the switch's `dune`,
   `ocamlformat`, and libraries on `PATH`. Without it you get `dune:
   command not found` or the wrong compiler.
2. **`PKG_CONFIG_PATH`** points at the user-local libcurl headers in
   `~/.local/ocaml-deps/usr`. Without it, `ezcurl` can fail to configure or
   link against the wrong libcurl. System development packages cover this on
   other machines, so the export is harmless there.
3. **`dune build`** compiles everything, including the vendored readability
   asset embedded at build time.

## Verify the environment

```sh
eval "$(opam env --switch=ocaml55)"
ocaml -version   # expect 5.5.x
which dune ocamlformat
```

## Notes

- `dune build` regenerates `sparks_rss.opam` from `dune-project`
  (`generate_opam_files`). If the two disagree, the build leaves the `.opam`
  file modified; keep that change when dependencies changed, or revert it when
  it is unrelated to the task.
- Do not run two `dune` commands in parallel in the same checkout. They share
  `_build` and its RPC server, and a concurrent invocation can fail with
  `Build requests require a watch-mode server`. Run them one after another.
- If the switch is missing, create it once with
  `opam switch create ocaml55 5.5.0`, then install dependencies:
  `opam install . --deps-only --with-test --with-doc -y`. The `webdriver`
  packages are pinned from git; see the README toolchain section.
- Running the CLI (`dune exec sparks_rss -- ...`) also needs Firefox and
  `geckodriver` on `PATH`. Building and testing do not.
- Use the `pre-pi-checks` skill to run the full CI gate after building.
