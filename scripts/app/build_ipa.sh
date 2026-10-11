#!/usr/bin/env bash
# Copyright (C) 2025 Laurynas 'Deviltry' Ekekeke
# SPDX-License-Identifier: AGPL-3.0-only

set -euo pipefail

usage() {
	cat <<'EOF_USAGE'
Usage: bash scripts/app/build_ipa.sh [--debug]

Build an unsigned PicoRC IPA for physical iPhones; AltStore signs it during installation.

  (default)   Release build.
  --debug     Debug build.
  --help      Show this help.
EOF_USAGE
}

fail() {
	printf '%s\n' "$*" >&2
	exit 1
}

configuration=Release
while (( $# > 0 )); do
	case "$1" in
		--debug) configuration=Debug; shift ;;
		--help|-h) usage; exit 0 ;;
		*) usage >&2; fail "Unknown argument: $1" ;;
	esac
done

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
build_dir="$repo_root/app/build"

# No debug dylib: AltStore installs a single executable
settings=()
[[ "$configuration" == Debug ]] && settings=(ENABLE_DEBUG_DYLIB=NO)

mkdir -p "$build_dir"

xcodebuild -quiet \
	-project "$repo_root/app/PicoRC.xcodeproj" \
	-scheme PicoRC \
	-configuration "$configuration" \
	-sdk iphoneos \
	-destination 'generic/platform=iOS' \
	-derivedDataPath "$build_dir/DerivedData" \
	CODE_SIGNING_ALLOWED=NO \
	${settings[@]+"${settings[@]}"} \
	build

package_dir=$(mktemp -d "$build_dir/ipa.XXXXXX")
trap 'rm -rf -- "$package_dir"' EXIT

mkdir "$package_dir/Payload"
ditto "$build_dir/DerivedData/Build/Products/$configuration-iphoneos/PicoRC.app" \
	"$package_dir/Payload/PicoRC.app"

(
	cd -- "$package_dir"
	/usr/bin/zip -q -r "$package_dir/PicoRC.ipa" Payload
)

mv "$package_dir/PicoRC.ipa" "$build_dir/PicoRC.ipa"
(
	cd -- "$build_dir"
	/usr/bin/zip -q "$package_dir/PicoRC-transfer.zip" PicoRC.ipa
)
mv "$package_dir/PicoRC-transfer.zip" "$build_dir/PicoRC-transfer.zip"
printf 'IPA (%s): %s\n' "$configuration" "$build_dir/PicoRC.ipa"
printf 'AirDrop ZIP: %s\n' "$build_dir/PicoRC-transfer.zip"
