.PHONY: build release clean

# Build the xcframework locally
build:
	./scripts/fetch-deps.sh
	./scripts/build-xcframework.sh

# Clean built artifacts
clean:
	rm -rf Frameworks/libghostty.xcframework
	rm -f Frameworks/libghostty.xcframework.zip

# Create a release: determine next version from conventional commits, build, tag, and publish
#
# Usage:
#   make release          # auto-detect version bump from conventional commits
#   make release BUMP=minor  # force a specific bump (major, minor, patch)
release: _check-clean _check-gh build
	$(eval LAST_TAG := $(shell git describe --tags --abbrev=0 2>/dev/null || echo ""))
	$(eval BUMP ?= $(shell $(MAKE) -s _detect-bump LAST_TAG="$(LAST_TAG)"))
	$(eval NEXT_VERSION := $(shell $(MAKE) -s _next-version LAST_TAG="$(LAST_TAG)" BUMP="$(BUMP)"))
	@echo "==> Releasing $(NEXT_VERSION) ($(BUMP) bump from $(or $(LAST_TAG),none))"
	@# Zip and checksum
	cd Frameworks && zip -r -y libghostty.xcframework.zip libghostty.xcframework/
	$(eval CHECKSUM := $(shell swift package compute-checksum Frameworks/libghostty.xcframework.zip))
	$(eval REPO_URL := $(shell gh repo view --json url -q .url))
	$(eval ASSET_URL := $(REPO_URL)/releases/download/$(NEXT_VERSION)/libghostty.xcframework.zip)
	@# Update Package.swift with release URL and checksum
	sed -i '' 's|^let xcframeworkURL = .*|let xcframeworkURL = "$(ASSET_URL)"|' Package.swift
	sed -i '' 's|^let xcframeworkChecksum = .*|let xcframeworkChecksum = "$(CHECKSUM)"|' Package.swift
	@# Commit, tag, and push
	git add Package.swift
	git commit -m "chore: update Package.swift for $(NEXT_VERSION) release"
	git tag "$(NEXT_VERSION)"
	git push origin main
	git push origin "$(NEXT_VERSION)"
	@# Create GitHub release with artifact
	gh release create "$(NEXT_VERSION)" \
		Frameworks/libghostty.xcframework.zip \
		--title "$(NEXT_VERSION)" \
		--generate-notes \
		--notes-start-tag "$(LAST_TAG)"
	@echo ""
	@echo "==> Released $(NEXT_VERSION)"
	@echo "    $(REPO_URL)/releases/tag/$(NEXT_VERSION)"

# --- Internal targets ---

_check-clean:
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "Error: working tree is not clean. Commit or stash changes first."; \
		exit 1; \
	fi

_check-gh:
	@if ! command -v gh >/dev/null 2>&1; then \
		echo "Error: gh CLI not found. Install from https://cli.github.com"; \
		exit 1; \
	fi
	@if ! gh auth status >/dev/null 2>&1; then \
		echo "Error: gh CLI not authenticated. Run: gh auth login"; \
		exit 1; \
	fi

# Detect bump type from conventional commits since last tag
# feat: -> minor, fix:/chore:/etc -> patch, BREAKING CHANGE or !: -> major
_detect-bump:
	@if [ -z "$(LAST_TAG)" ]; then \
		echo "minor"; \
	elif git log "$(LAST_TAG)"..HEAD --pretty="%s%n%b" | grep -qE "^BREAKING CHANGE:|^[a-z]+(\(.*\))?!:"; then \
		echo "major"; \
	elif git log "$(LAST_TAG)"..HEAD --pretty="%s" | grep -qE "^feat(\(.*\))?:"; then \
		echo "minor"; \
	else \
		echo "patch"; \
	fi

# Calculate next semver from last tag and bump type
_next-version:
	@if [ -z "$(LAST_TAG)" ]; then \
		echo "v0.1.0"; \
	else \
		version=$$(echo "$(LAST_TAG)" | sed 's/^v//'); \
		major=$$(echo "$$version" | cut -d. -f1); \
		minor=$$(echo "$$version" | cut -d. -f2); \
		patch=$$(echo "$$version" | cut -d. -f3); \
		case "$(BUMP)" in \
			major) echo "v$$((major + 1)).0.0" ;; \
			minor) echo "v$$major.$$((minor + 1)).0" ;; \
			patch) echo "v$$major.$$minor.$$((patch + 1))" ;; \
		esac; \
	fi
