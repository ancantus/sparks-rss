.PHONY: default
default: build

.PHONY: default format build clean doc epubcheck update-readability
build:
	dune build

format: 
	dune build @fmt --auto-promote

clean:
	dune clean

doc: 
	dune build @doc

epubcheck:
	dune exec test/test_epubcheck.exe

update-readability:
	tools/update-readability.sh $(TAG)
