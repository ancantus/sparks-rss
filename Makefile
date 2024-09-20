.PHONY: default
default: build

.PHONY: format build
build:
	dune build

.PHONY: format
format: 
	dune build @fmt --auto-promote

.PHONY: clean
clean:
	dune clean

.PHONY: doc
doc: 
	dune build @doc

.PHONY: run
run:
	dune exec sparks_rss
