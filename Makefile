.PHONY: test update fmt fmt-check lint check keymaps

# stylua lives in mason's package dir, not on PATH — nvim's own PATH munging in
# globals.lua is not inherited by make. Fall back to PATH so this works on a
# machine where stylua was installed another way.
STYLUA := $(shell command -v stylua 2>/dev/null || echo $(HOME)/.local/share/nvim/mason/bin/stylua)
LUA_SOURCES := init.lua lua tests scripts

# Route to the real harness. scripts/test.sh runs each spec with `nvim -l` and
# watches three failure channels at once (FAIL: lines, non-zero exit, and nvim
# E-codes). Do NOT swap this for PlenaryBustedDirectory — the specs call
# `vim.cmd 'cq'` themselves and are not written against plenary's busted runner.
#
# `test` deliberately does NOT depend on fmt/lint. 43 files in this tree have
# pre-existing stylua drift; gating the suite on formatting would turn a green
# run red for a reason that has nothing to do with the specs.
test:
	./scripts/test.sh

# Headless update for scripted/agentic maintenance. The bang matters: it forces
# re-cloning even when the git dir is already at the recorded commit.
update:
	nvim --headless "+Lazy! sync" +qa

# Rewrite every lua file in stylua.toml's style. Separate rung from test.
fmt:
	@command -v $(STYLUA) >/dev/null 2>&1 || { echo "stylua not found at $(STYLUA)"; echo "install: nvim --headless '+MasonInstall stylua' +qa"; exit 1; }
	$(STYLUA) $(LUA_SOURCES)
	@echo "fmt: stylua rewrote $(LUA_SOURCES)"

# Non-mutating form of fmt. The tree is stylua-clean, so this is green and
# worth keeping green -- it is the gate that stops drift accumulating.
#
# It was red on 42 files, and the old comment here claimed that drift was
# "load-bearing" because tests/terminal_colors_spec.lua located functions in
# terminal-colors.lua by hardcoded line number. That was backwards: the
# brittleness was the line anchors, not the formatting. The spec now finds each
# region by matching the definition itself, so `make fmt` and `make test` no
# longer conflict. If this ever goes red, run `make fmt` -- do NOT go looking
# for line numbers to update.
fmt-check:
	@command -v $(STYLUA) >/dev/null 2>&1 || { echo "stylua not found at $(STYLUA)"; exit 1; }
	$(STYLUA) --check $(LUA_SOURCES)

# luacheck is not installed on this machine, is not in lazy-lock.json, and this
# repo has NO .luacheckrc -- there is no configured luacheck config to wire up,
# only stylua.toml. Say so plainly instead of exiting 127 with no explanation.
# Default globals live in lua/globals.lua; luacheck would need --globals vim or
# a config file to read anything useful here.
lint:
	@if command -v luacheck >/dev/null 2>&1; then \
		luacheck $(LUA_SOURCES); \
	else \
		echo "luacheck not installed -- lint did NOT run."; \
		echo "A skipping gate exits 0 and reports green while doing nothing."; \
		echo "install: luarocks install luacheck   (or drop it in mason)"; \
		exit 1; \
	fi

# Everything that can be green today: the suite, plus whatever linters exist,
# plus the style gate. fmt-check is safe to include now that the colour spec no
# longer locates functions by line number — the reason it used to be excluded.
check: test lint fmt-check

# The verification path AGENT.md:242 documents for keymap changes. Bootstraps
# its own probe git repo at /tmp/probe_repo so gitsigns' buffer maps attach.
keymaps:
	nvim --headless -u init.lua -c "luafile scripts/keymaps-dump.lua" -c "qa!"
	@echo "keymaps: wrote ~/.cache/nvim/keymaps_dump.json"
