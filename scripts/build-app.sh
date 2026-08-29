#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
release_dir="$project_dir/dist"
app_dir="$release_dir/Codex Tidy.app"
version="0.1.0"
release_label="${RELEASE_LABEL:-beta.1}"
zip_path="$release_dir/Codex-Tidy-macOS-universal-v${version}-${release_label}.zip"
product_dir="$project_dir/.build/apple/Products/Release"
icon_path="$project_dir/.build/generated/AppIcon.icns"

cd "$project_dir"
swift build -c release --arch arm64 --arch x86_64 --product CodexFileManager
swift build -c release --arch arm64 --arch x86_64 --product codexfm
"$script_dir/generate-icon.sh" "$icon_path"

if [[ "$app_dir" != "$project_dir"/dist/* ]]; then
    print -u2 "拒绝写入项目 dist 目录之外的位置"
    exit 1
fi

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources" "$release_dir/bin"
cp "$product_dir/CodexFileManager" "$app_dir/Contents/MacOS/CodexFileManager"
cp "Resources/Info.plist" "$app_dir/Contents/Info.plist"
cp "$icon_path" "$app_dir/Contents/Resources/AppIcon.icns"
cp "$product_dir/codexfm" "$release_dir/bin/codexfm"

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    codesign --force --deep --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$app_dir"
    print "已使用 Developer ID 签名：$DEVELOPER_ID_APPLICATION"
else
    codesign --force --deep --sign - "$app_dir"
    print "已使用 ad-hoc 签名（公开测试版会触发 Gatekeeper 提示）"
fi

rm -f "$zip_path"
ditto --norsrc -c -k --keepParent "$app_dir" "$zip_path"

if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
    if [[ -z "${DEVELOPER_ID_APPLICATION:-}" ]]; then
        print -u2 "设置 NOTARYTOOL_PROFILE 时也必须设置 DEVELOPER_ID_APPLICATION"
        exit 1
    fi
    xcrun notarytool submit "$zip_path" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
    xcrun stapler staple "$app_dir"
    rm -f "$zip_path"
    ditto --norsrc -c -k --keepParent "$app_dir" "$zip_path"
    print "Apple 公证完成并已装订票据"
fi

print "已生成：$app_dir"
print "发布包：$zip_path"
print "只读 CLI：$release_dir/bin/codexfm"
