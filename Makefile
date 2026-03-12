.PHONY: fetch-deps xcframework build release clean

# Fetch deps + build xcframework (full setup)
build:
	./scripts/fetch-deps.sh
	./scripts/build-xcframework.sh

# Initialize submodule and prefetch Zig build dependencies
fetch-deps:
	./scripts/fetch-deps.sh

# Build the universal xcframework from Ghostty source
xcframework:
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
	@last_tag=$$(git describe --tags --abbrev=0 2>/dev/null || echo ""); \
	bump=$${BUMP:-$$($(MAKE) -s _detect-bump LAST_TAG="$$last_tag")}; \
	next_version=$$($(MAKE) -s _next-version LAST_TAG="$$last_tag" BUMP="$$bump"); \
	echo "==> Releasing $$next_version ($$bump bump from $${last_tag:-none})"; \
	cd Frameworks && zip -r -y libghostty.xcframework.zip libghostty.xcframework/ && cd ..; \
	checksum=$$(swift package compute-checksum Frameworks/libghostty.xcframework.zip); \
	if [ -z "$$checksum" ]; then \
		echo "Error: failed to compute checksum"; \
		exit 1; \
	fi; \
	repo_url=$$(gh repo view --json url -q .url); \
	asset_url="$$repo_url/releases/download/$$next_version/libghostty.xcframework.zip"; \
	echo "  URL:      $$asset_url"; \
	echo "  Checksum: $$checksum"; \
	sed -i '' "s|^let xcframeworkURL = .*|let xcframeworkURL = \"$$asset_url\"|" Package.swift; \
	sed -i '' "s|^let xcframeworkChecksum = .*|let xcframeworkChecksum = \"$$checksum\"|" Package.swift; \
	git add Package.swift; \
	git commit -m "chore: update Package.swift for $$next_version release"; \
	git tag "$$next_version"; \
	git push origin main; \
	git push origin "$$next_version"; \
	gh release create "$$next_version" \
		Frameworks/libghostty.xcframework.zip \
		--title "$$next_version" \
		--generate-notes \
		--notes-start-tag "$$last_tag"; \
	echo ""; \
	echo "==> Released $$next_version"; \
	echo "    $$repo_url/releases/tag/$$next_version"

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
