#!/bin/bash
set -euo pipefail

probe_source="$SRCROOT/companion/StarHubFR.Probe"
probe_binary="$probe_source/bin/Release/net6.0/StarHubFR.Probe.dll"
destination="$1/Probe/StarHubFR Probe"

if [[ ! -f "$probe_binary" ]]; then
    echo "error: Build the StarHub probe with dotnet build -c Release before archiving." >&2
    exit 1
fi

newer_sources=$(find "$probe_source" -maxdepth 1 \( -name '*.cs' -o -name '*.csproj' -o -name manifest.json \) -newer "$probe_binary" -print)
newer_translations=$(find "$probe_source/i18n" -name '*.json' -newer "$probe_binary" -print)
if [[ -n "$newer_sources$newer_translations" ]]; then
    echo "error: The bundled probe is older than its sources. Use scripts/release.sh." >&2
    exit 1
fi

mkdir -p "$destination/i18n"
cp "$probe_binary" "$probe_source/manifest.json" "$probe_source/LICENSE-THIRD-PARTY.md" "$destination/"
cp "$probe_source"/i18n/*.json "$destination/i18n/"
