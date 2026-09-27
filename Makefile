.PHONY: test update

# Route to the real harness. scripts/test.sh runs each spec with `nvim -l` and
# watches three failure channels at once (FAIL: lines, non-zero exit, and nvim
# E-codes). Do NOT swap this for PlenaryBustedDirectory — the specs call
# `vim.cmd 'cq'` themselves and are not written against plenary's busted runner.
test:
	./scripts/test.sh

# Headless update for scripted/agentic maintenance. The bang matters: it forces
# re-cloning even when the git dir is already at the recorded commit.
update:
	nvim --headless "+Lazy! sync" +qa
