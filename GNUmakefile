elko.lua: assemble-elko.lua src/top.lua src/exit_guard.lua src/lex.lua src/err_at.lua src/find_linebreak_positions.lua src/tokenize.lua src/main.lua
	./$^ > $@ || (rm $@; false)
	chmod +x $@

bin/demo: src/demo.c
	@mkdir -p bin
	cc $^ -o $@

src/demo.c: src/demo.elko elko.lua
	./elko.lua $< -o $@

