.PHONY: toc_check toc_update watch dev build

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

dev: toc_check
	@wow-build-tools build -d -t "Endeavoring" -r ./.release --skipChangelog

build: toc_check
	@wow-build-tools build -d -t "Endeavoring" -r ./.release
