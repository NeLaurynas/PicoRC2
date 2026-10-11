#!/usr/bin/env bash
# Copyright (C) 2025 Laurynas 'Deviltry' Ekekeke
# SPDX-License-Identifier: AGPL-3.0-only

set -euo pipefail

usage() {
	cat <<'EOF'
Usage: bash scripts/app/update.sh [--debug] [--device NAME_OR_ID] [--skip-build]

Build PicoRC, copy its IPA to a paired iPhone and open it in AltStore.
Works over Wi-Fi or USB. Keep the iPhone unlocked and AltServer installed.

  --debug              Debug build; the default is a Release build.
  --device NAME_OR_ID  Select an iPhone when more than one is paired.
  --skip-build         Use the existing app/build/PicoRC.ipa.
  --help               Show this help.
EOF
}

fail() {
	printf '%s\n' "$*" >&2
	exit 1
}

value() {
	/usr/bin/plutil -extract "$2" raw -o - "$1"
}

device=
skip_build=false
build_args=()

while (( $# > 0 )); do
	case "$1" in
		--device)
			(( $# >= 2 )) && [[ -n "$2" ]] || fail '--device needs an iPhone name or identifier.'
			device=$2
			shift 2
			;;
		--debug) build_args=(--debug); shift ;;
		--skip-build) skip_build=true; shift ;;
		--help|-h) usage; exit 0 ;;
		*) usage >&2; fail "Unknown argument: $1" ;;
	esac
done

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
ipa="$repo_root/app/build/PicoRC.ipa"
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/picorc-app.XXXXXX")
trap 'rm -rf -- "$work_dir"' EXIT

if [[ -z "$device" ]]; then
	xcrun devicectl list devices --quiet --timeout 30 \
		--filter "properties.hardware.reality = 'physical' AND properties.hardware.deviceType = 'iPhone' AND properties.state.bootState = 'booted'" \
		--json-output "$work_dir/devices.json"

	count=$(value "$work_dir/devices.json" result.devices)
	case "$count" in
		0) fail 'No paired iPhone found. Pair it in Xcode Device Hub and join the same Wi-Fi network.' ;;
		1) device=$(value "$work_dir/devices.json" result.devices.0.identifier) ;;
		*)
			for (( index = 0; index < count; index++ )); do
				printf 'iPhone: %s\n' "$(value "$work_dir/devices.json" "result.devices.$index.properties.state.name")" >&2
			done
			fail 'Choose an iPhone with --device NAME_OR_ID.'
			;;
	esac
fi

if ! xcrun devicectl device info apps --device "$device" --quiet --timeout 30 \
	--include-container-paths \
	--filter "bundleIdentifier CONTAINS 'com.rileytestut.AltStore'" \
	--json-output "$work_dir/apps.json"; then
	fail 'Cannot reach the iPhone. Unlock it and check its connection in Xcode Device Hub.'
fi

count=$(value "$work_dir/apps.json" result.apps)
[[ "$count" == 1 ]] || fail "Expected one AltStore Classic installation on the iPhone; found $count."
altstore_id=$(value "$work_dir/apps.json" result.apps.0.bundleIdentifier)
container_path=$(value "$work_dir/apps.json" result.apps.0.dataContainerPath 2>/dev/null) \
	|| fail 'AltStore has no accessible app container. Check Developer Mode and Xcode device pairing.'
[[ -n "$container_path" ]] || fail 'AltStore has no accessible app container.'

if [[ "$skip_build" == false ]]; then
	bash "$script_dir/build_ipa.sh" ${build_args[@]+"${build_args[@]}"}
fi
[[ -f "$ipa" ]] || fail "IPA not found: $ipa"

open -g -a AltServer

printf 'Copying PicoRC to the iPhone...\n'
xcrun devicectl device copy to --device "$device" --timeout 60 \
	--domain-type appDataContainer --domain-identifier "$altstore_id" \
	--source "$ipa" --destination Documents/PicoRC.ipa

printf 'Opening the IPA in AltStore...\n'
if ! xcrun devicectl device process launch --device "$device" --timeout 30 \
	--terminate-existing --payload-url "file://$container_path/Documents/PicoRC.ipa" \
	"$altstore_id"; then
	fail 'IPA transferred, but AltStore could not open. Unlock the iPhone, check its connection and rerun with --skip-build.'
fi

printf 'IPA handed to AltStore. Complete any prompts on the iPhone and check PicoRC in My Apps.\n'
