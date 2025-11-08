TESTS_INIT=tests/minimal_init.lua
TESTS_DIR=tests/
PLENARY_DIR=${XDG_DATA_HOME}/nvim/lazy/plenary.nvim
PANVIMDOC=~/src/panvimdoc/panvimdoc.sh


.PHONY: test doc

test:
	@PLENARY_DIR=${PLENARY_DIR} nvim \
		--headless \
		--noplugin \
		-u ${TESTS_INIT} \
		-c "PlenaryBustedDirectory ${TESTS_DIR} { minimal_init = '${TESTS_INIT}' }"

doc:
	@$(PANVIMDOC) --project-name codegpt --input-file doc/codegpt.md --vim-version 'Neovim 0.8+' --toc --demojify --output-file doc/codegpt.txt --treesitter true

