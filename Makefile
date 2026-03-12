.PHONY: fetch-deps xcframework build clean

# Fetch deps + build xcframework (full setup)
build: fetch-deps xcframework

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
