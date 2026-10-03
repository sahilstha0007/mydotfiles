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

# Non-mutating form of fmt. Currently RED on pre-existing drift, and that drift
# is load-bearing: tests/terminal_colors_spec.lua slices lua/plugins/ui/
# terminal-colors.lua by LINE NUMBER and asserts on the exact text at lines
# 116/141/170/191/227. stylua reflows those comments and every anchor moves, so
# running `make fmt` turns a green suite red.
#
# To clear the drift: run `make fmt`, then update the line numbers in
# tests/terminal_colors_spec.lua (its failure output names each one), and
# re-run `make test`. Do not relax the anchors to make it pass.
fmt-check:
	@command -v $(STYLUA) >/dev/null 2>&1 || { echo "stylua not found at $(STYLUA)"; exit 1; }
	$(STYLUA) --check $(LUA_SOURCES)

# luacheck is not installed on this machine and is not in lazy-lock.json. Say so
# plainly instead of exiting 127 with no explanation.
lint:
	@if command -v luacheck >/dev/null 2>&1; then \
		luacheck $(LUA_SOURCES); \
	else \
		echo "luacheck not installed - skipping."; \
		echo "install: luarocks install luacheck   (or drop it in mason)"; \
	fi

# Everything that can be green today: the suite plus whatever linters exist.
# fmt-check is deliberately NOT here — it is red on pre-existing drift, and
# folding it in would make this command permanently red and therefore ignored.
# Run `make fmt` to clear it, then add it back if you want the style gate.
check: test lint

# The verification path AGENT.md:242 documents for keymap changes. Bootstraps
# its own probe git repo at /tmp/probe_repo so gitsigns' buffer maps attach.
keymaps:
	nvim --headless -u init.lua -c "luafile scripts/keymaps-dump.lua" -c "qa!"
	@echo "keymaps: wrote ~/.cache/nvim/keymaps_dump.json"
