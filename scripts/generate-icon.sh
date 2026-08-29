#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
output_path="${1:-$project_dir/.build/generated/AppIcon.icns}"
temporary_dir="$(mktemp -d)"
iconset_dir="$temporary_dir/AppIcon.iconset"

cleanup() {
    rm -rf "$temporary_dir"
}
trap cleanup EXIT

mkdir -p "$iconset_dir" "${output_path:h}"
xcrun swift "$script_dir/generate-icon.swift" "$temporary_dir/icon-1024.png"

typeset -a icon_specs
icon_specs=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
)

for spec in "${icon_specs[@]}"; do
    size="${spec%%:*}"
    filename="${spec#*:}"
    sips -z "$size" "$size" "$temporary_dir/icon-1024.png" --out "$iconset_dir/$filename" >/dev/null
done

iconutil -c icns "$iconset_dir" -o "$output_path"
