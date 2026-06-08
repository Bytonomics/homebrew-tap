.PHONY: check check-current check-release

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
