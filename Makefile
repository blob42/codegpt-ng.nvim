TESTS_INIT=tests/minimal_init.lua
TESTS_DIR=tests/
PLENARY_DIR=${XDG_DATA_HOME}/nvim/lazy/plenary.nvim


.PHONY: test

test:
	@PLENARY_DIR=${PLENARY_DIR} nvim \
		--headless \
		--noplugin \
		-u ${TESTS_INIT} \
		-c "PlenaryBustedDirectory ${TESTS_DIR} { minimal_init = '${TESTS_INIT}' }"
