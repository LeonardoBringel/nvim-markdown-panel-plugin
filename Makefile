NVIM ?= nvim
PLENARY_DIR ?= .tests/deps/plenary.nvim
PLENARY_ABS := $(abspath $(PLENARY_DIR))
XDG_ROOT := $(CURDIR)/.tests/xdg

export PLENARY_DIR := $(PLENARY_ABS)
export XDG_CONFIG_HOME := $(XDG_ROOT)/config
export XDG_DATA_HOME := $(XDG_ROOT)/data
export XDG_STATE_HOME := $(XDG_ROOT)/state
export XDG_CACHE_HOME := $(XDG_ROOT)/cache

.PHONY: deps test test-unit lint

deps:
	@[ -d "$(PLENARY_ABS)" ] || git clone --depth 1 https://github.com/nvim-lua/plenary.nvim "$(PLENARY_ABS)"
	@mkdir -p "$(XDG_CONFIG_HOME)" "$(XDG_DATA_HOME)" "$(XDG_STATE_HOME)" "$(XDG_CACHE_HOME)"

test-unit: deps
	$(NVIM) --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/unit { minimal_init = 'tests/minimal_init.lua', sequential = true }"

test: deps
	$(NVIM) --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests { minimal_init = 'tests/minimal_init.lua', sequential = true }"

lint:
	VIMRUNTIME="$$($(NVIM) --clean --headless -c 'lua io.write(vim.env.VIMRUNTIME)' -c 'qa!')" \
		lua-language-server --check . --checklevel=Warning --check_format=pretty --logpath="$(CURDIR)/.tests/luals"
