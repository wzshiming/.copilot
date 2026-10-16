PRETTIER := npx --yes prettier@3.9.6
MARKDOWNLINT := npx --yes markdownlint-cli2@0.17.2
BATS := npx --yes bats@1.13.0
SHELLCHECK := shellcheck -s sh
HOOK_TESTS := hooks/pre-tool-use.test.mjs hooks/subagent-start.test.mjs hooks/worktree.test.mjs

.PHONY: check format-check lint test format

check: format-check lint test

format-check:
	$(PRETTIER) --check "**/*.{md,mjs,json}"

lint:
	$(MARKDOWNLINT) "**/*.md"
	$(SHELLCHECK) scripts/*.sh

test: $(HOOK_TESTS)
	$(BATS) tests
	node --test $(HOOK_TESTS)

format:
	$(PRETTIER) --write "**/*.{md,mjs,json}"
