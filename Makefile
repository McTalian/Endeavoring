.PHONY: toc_check toc_update watch dev build test test-only test-cov test-file test-pattern test-ci lua_deps

ROCKSBIN := $(HOME)/.luarocks/bin

dev: toc_check
	@wow-build-tools build -d -t "Endeavoring" -r ./.release --skipChangelog

toc_check:
	@wow-build-tools toc check \
		-a "Endeavoring" \
		-x embeds.xml \
		--no-splash \
		-b -p

toc_update:
	@wow-build-tools toc update \
		-a "Endeavoring" \
		--no-splash \
		-b -p

watch: toc_check
	@wow-build-tools build watch -t "Endeavoring" -r ./.release

build: toc_check
	@wow-build-tools build -d -t "Endeavoring" -r ./.release

test:
	@$(ROCKSBIN)/busted Endeavoring_spec

test-only:
	@$(ROCKSBIN)/busted --tags=only Endeavoring_spec

# Run tests with coverage
test-cov:
	@rm -rf luacov-html && rm -rf luacov.*out && mkdir -p luacov-html && $(ROCKSBIN)/busted --coverage Endeavoring_spec && $(ROCKSBIN)/luacov && echo "\nCoverage report generated at luacov-html/index.html"

# Run tests for a specific file
# Usage: make test-file FILE=Endeavoring_spec/Sync/Protocol_spec.lua
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=path/to/test_file.lua"; \
		exit 1; \
	fi
	@$(ROCKSBIN)/busted --verbose "$(FILE)"

# Run tests matching a specific pattern
# Usage: make test-pattern PATTERN="NormalizeKeys"
test-pattern:
	@if [ -z "$(PATTERN)" ]; then \
		echo "Usage: make test-pattern PATTERN=\"test description\""; \
		exit 1; \
	fi
	@$(ROCKSBIN)/busted --verbose --filter="$(PATTERN)" Endeavoring_spec

test-ci:
	@rm -rf luacov-html && rm -rf luacov.*out && mkdir -p luacov-html && $(ROCKSBIN)/busted --coverage -o=TAP Endeavoring_spec && $(ROCKSBIN)/luacov

lua_deps:
	@luarocks install endeavoring-1-1.rockspec --local --force --lua-version 5.4
	@luarocks install busted --local --force --lua-version 5.4
