FROM ocaml/opam2
RUN opam switch create operf 4.02.3
RUN sudo apt install -y m4 python3 tmux vim && \
		opam pin add -y -k git git://github.com/kayceesrk/ocaml-perf && \
		opam pin add -y -k git git://github.com/kayceesrk/operf-macro#opam2 && \
		opam install yojson re
RUN cd && \
		git clone https://github.com/kayceesrk/ocamlbench-scripts.git && \
		cd ocamlbench-scripts && \
		git checkout dockerfile && \
		eval $(opam env) && \
		echo $PATH && \
		sh -c "make opamjson2html.native" && \
		opam repo add benches git+https://github.com/kayceesrk/ocamlbench-repo#multicore -a
