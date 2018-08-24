#!/bin/bash

# Run for the initial setup.

opam create operf 4.02.3
opam pin add -y -k git git://github.com/kayceesrk/ocaml-perf
opam pin add -y -k git git://github.com/OCamlPro/operf-macro#opam2
opam install yojson re
make opamjson2html.native
opam repo add benches git+https://github.com/kayceesrk/ocamlbench-repo#multicore -a
