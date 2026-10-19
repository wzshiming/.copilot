PRETTIER := npx --yes prettier@3.9.6
MARKDOWNLINT := npx --yes markdownlint-cli2@0.17.2
BATS := npx --yes bats@1.13.0
SHELLCHECK := shellcheck -s sh

.PHONY: check format-check lint test format

check: format-check lint test

format-check:
	$(PRETTIER) --check "**/*.md"

lint:
	$(MARKDOWNLINT) "**/*.md"
	$(SHELLCHECK) scripts/*.sh hooks/*.sh

test:
	$(BATS) tests

format:
	$(PRETTIER) --write "**/*.md"
