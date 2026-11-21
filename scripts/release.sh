#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
probe_project=companion/StarHubFR.Probe/StarHubFR.Probe.csproj
probe_binary=companion/StarHubFR.Probe/bin/Release/net6.0/StarHubFR.Probe.dll
plist=/usr/libexec/PlistBuddy
version=$("$plist" -c 'Print :CFBundleShortVersionString' Info.plist)
previous_build=$("$plist" -c 'Print :CFBundleVersion' Info.plist)
if [[ ! "$previous_build" =~ ^[0-9]+$ ]]; then
    echo "CFBundleVersion must be an integer." >&2
    exit 1
fi

if ! command -v dotnet >/dev/null; then
    echo "Install the .NET SDK to build the bundled StarHub probe." >&2
    exit 1
fi

game_path="${GamePath:-$HOME/Library/Application Support/Steam/steamapps/common/Stardew Valley/Contents/MacOS}"
if [[ ! -d "$game_path" && -z "${GamePath:-}" ]]; then
    game_path="/Applications/Stardew Valley.app/Contents/MacOS"
fi
if [[ ! -d "$game_path" ]]; then
    echo "Set GamePath to the Stardew Valley Contents/MacOS directory." >&2
    exit 1
fi

swift scripts/check-localizations.swift
dotnet build "$probe_project" -c Release --nologo "-p:GamePath=$game_path"
test -f "$probe_binary"
# MSBuild can reuse the DLL when only its separately packaged metadata changed.
touch "$probe_binary"
"$plist" -c "Set :CFBundleVersion $((10#$previous_build + 1))" Info.plist

mkdir -p bundles .build
staging="$(mktemp -d "$PWD/.build/release.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
archive="$staging/StarHub.xcarchive"
xcodebuild -project StarHub.xcodeproj -scheme StarHub -destination 'generic/platform=macOS' \
    -archivePath "$archive" STARHUB_EMBED_PROBE=YES \
    "CODE_SIGN_IDENTITY=${STARHUB_SIGNING_IDENTITY:--}" archive

app="$archive/Products/Applications/StarHub.app"
test -f "$app/Contents/Resources/Probe/StarHubFR Probe/StarHubFR.Probe.dll"
codesign --verify --deep --strict "$app"
zip="StarHub_v$version.zip"
ditto -c -k --keepParent "$app" "$staging/$zip"
(cd "$staging" && shasum -a 256 "$zip" > SHA256SUMS)
mv "$staging/$zip" "$staging/SHA256SUMS" bundles/
echo "Release files: bundles/$zip and bundles/SHA256SUMS"
