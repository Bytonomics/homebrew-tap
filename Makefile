.PHONY: check check-current check-release render

check:
	bash .github/scripts/validate-formula.sh fixture

check-current:
	bash .github/scripts/validate-formula.sh current

check-release:
	@if [ -z "$(VERSION)" ]; then \
		echo "VERSION is required (usage: make check-release VERSION=X.Y.Z)" >&2; \
		exit 1; \
	fi
	bash .github/scripts/validate-formula.sh release "$(VERSION)"

# Regenerate every packaged/generated file that is sourced from a
# template, in place, at its exact tracked path. This is the single
# entry point pre-commit runs before check-formula-freshness - never
# hand-edit a generated file. Defaults to the version already pinned
# in the current formula (so a template-only edit, e.g. a caveats
# wording change, needs no VERSION argument); pass VERSION=X.Y.Z to
# target a different release explicitly.
#
# To add another generated file later, append another backslash-
# continued command below using the same $$version, so this stays one
# target instead of growing a new target per generated file.
render:
	@version="$(VERSION)"; \
	if [ -z "$$version" ]; then \
		version="$$(grep -m1 'cld-gateway-v[0-9]' Formula/cld-gateway.rb | sed -E 's|.*cld-gateway-v([0-9]+\.[0-9]+\.[0-9]+[^/]*).*|\1|')"; \
	fi; \
	if [ -z "$$version" ]; then \
		echo "Could not determine version from Formula/cld-gateway.rb; pass VERSION=X.Y.Z" >&2; \
		exit 1; \
	fi; \
	echo "Rendering Formula/cld-gateway.rb for version $$version"; \
	python3 .github/scripts/render-formula.py --version "$$version" --output Formula/cld-gateway.rb
