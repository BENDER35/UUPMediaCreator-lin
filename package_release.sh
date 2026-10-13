#!/usr/bin/env bash
#
# Build the release zip containing the UUPMediaCreator command line tools and
# the documentation.
#
# Contents:
#   bin/linux-x64/    UUPDownload, UUPMediaConverter
#   bin/linux-arm64/  UUPDownload, UUPMediaConverter
#   bin/win-x64/      UUPDownload.exe, UUPMediaConverter.exe
#   README.md, README.es.md
#   docs/             TECHNICAL_GUIDE.md, GUIA_TECNICA.md
#
# The binaries are self-contained single-file executables: they do NOT require
# the .NET runtime to be installed on the target machine.
#
# Usage:
#   ./package_release.sh [version]
#
# If no version is given, it is read from src/Applications/UUPDownload/Properties/AssemblyInfo.cs.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="${1:-$(grep -oP 'AssemblyVersion\("\K[0-9.]+' "${SCRIPT_DIR}/src/Applications/UUPDownload/Properties/AssemblyInfo.cs")}"
RIDS=(linux-x64 linux-arm64 win-x64)
STAGE="${SCRIPT_DIR}/publish/release"
OUT_ZIP="${SCRIPT_DIR}/publish/UUPMediaCreator-lin-v${VERSION}.zip"

echo "==> Packaging UUPMediaCreator-lin v${VERSION}"

rm -rf "${STAGE}"
mkdir -p "${STAGE}/bin"

for rid in "${RIDS[@]}"; do
    echo "==> Publishing ${rid}"
    out="${STAGE}/bin/${rid}"
    mkdir -p "${out}"
    for proj in \
        "src/Applications/UUPDownload/UUPDownload.csproj" \
        "src/Applications/UUPMediaConverter/UUPMediaConverter.csproj"; do
        dotnet publish "${SCRIPT_DIR}/${proj}" \
            --configuration Release \
            --runtime "${rid}" \
            -p:SelfContained=true \
            -p:PublishSingleFile=true \
            -p:PublishTrimmed=false \
            --output "${out}"
    done
    find "${out}" -maxdepth 1 -name '*.pdb' -delete
done

cp "${SCRIPT_DIR}/README.md" "${SCRIPT_DIR}/README.es.md" "${STAGE}/"
rm -rf "${STAGE}/docs"
mkdir -p "${STAGE}/docs"
cp "${SCRIPT_DIR}"/docs/*.md "${STAGE}/docs/"

echo "==> Creating ${OUT_ZIP}"
rm -f "${OUT_ZIP}"
( cd "${STAGE}" && zip -r -q "${OUT_ZIP}" . )

echo "==> Done: ${OUT_ZIP}"
ls -la "${OUT_ZIP}"
echo "==> Contents:"
unzip -l "${OUT_ZIP}"
