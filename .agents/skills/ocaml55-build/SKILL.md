---
name: ocaml55-build
description: Build sparks-rss with the ocaml55 opam switch. Use when building, compiling, or running dune targets in this repository.
---

# OCaml 5.5 Build

The project builds with OCaml 5.5 in the `ocaml55` opam switch.

```sh
.agents/skills/ocaml55-build/scripts/build.sh
```

The script activates the switch, sets the libcurl `PKG_CONFIG_PATH`, and runs
`dune build`. Extra arguments pass through to dune (e.g. `scripts/build.sh
@doc`). See the script comments for the environment details.

If the switch or dependencies are missing, stop and ask the user to set them
up; do not create switches or install packages automatically.

Use the `pre-pi-checks` skill for the full gate.
