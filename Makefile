WARN=+1..45-4-44-42

opamjson2html.native: opamjson2html.ml
	ocamlbuild -package yojson,re $@

clean:
	ocamlbuild -clean
	rm -f *~
