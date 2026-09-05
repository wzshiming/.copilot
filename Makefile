PRETTIER := npx --yes prettier@3.9.6
MARKDOWNLINT := npx --yes markdownlint-cli2@0.17.2

.PHONY: check format-check lint format

check: format-check lint

format-check:
	$(PRETTIER) --check "**/*.md"

lint:
	$(MARKDOWNLINT) "**/*.md"

format:
	$(PRETTIER) --write "**/*.md"
