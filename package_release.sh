#!/usr/bin/env bash
#
# Build the release zip containing the UUPMediaCreator command line tools and
# the documentation.
#
# Contents:
#   bin/linux-x64/        UUPDownload, UUPMediaConverter
#   bin/linux-arm64/      UUPDownload, UUPMediaConverter
#   bin/win-x64/          UUPDownload.exe, UUPMediaConverter.exe  (.NET 10)
#   bin/win-x86/          UUPDownload.exe, UUPMediaConverter.exe  (.NET 10, 32-bit)
#   bin/win-legacy-x64/   UUPDownload.exe, UUPMediaConverter.exe  (.NET 6, Windows 7 SP1+)
#   bin/win-legacy-x86/   UUPDownload.exe, UUPMediaConverter.exe  (.NET 6, Windows 7 SP1+)
#   README.md, README.es.md
#   docs/                 TECHNICAL_GUIDE.md, GUIA_TECNICA.md
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
RIDS=(linux-x64 linux-arm64 win-x64 win-x86)
LEGACY_RIDS=(x64 x86)
CLI_PROJECTS=(
    "src/Applications/UUPDownload/UUPDownload.csproj"
    "src/Applications/UUPMediaConverter/UUPMediaConverter.csproj"
)
STAGE="${SCRIPT_DIR}/publish/release"
OUT_ZIP="${SCRIPT_DIR}/publish/UUPMediaCreator-lin-v${VERSION}.zip"

echo "==> Packaging UUPMediaCreator-lin v${VERSION}"

rm -rf "${STAGE}"
mkdir -p "${STAGE}/bin"

for rid in "${RIDS[@]}"; do
    echo "==> Publishing ${rid}"
    out="${STAGE}/bin/${rid}"
    mkdir -p "${out}"
    for proj in "${CLI_PROJECTS[@]}"; do
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

# Legacy flavour: targets .NET 6, the last .NET runtime that runs on
# Windows 7 SP1 / 8 / 8.1 (the default net10.0 requires Windows 10 1607+).
# The framework is selected through the UUPMediaTargetFramework property
# (Directory.Build.props); LangVersion=latest is required because a few files
# use language features newer than the C# 10 default of net6.0.
for arch in "${LEGACY_RIDS[@]}"; do
    rid="win-${arch}"
    echo "==> Publishing legacy (net6.0) ${rid}"
    out="${STAGE}/bin/win-legacy-${arch}"
    mkdir -p "${out}"
    for proj in "${CLI_PROJECTS[@]}"; do
        dotnet msbuild "${SCRIPT_DIR}/${proj}" '/t:restore;publish' \
            /p:Configuration=Release \
            /p:RuntimeIdentifier="${rid}" \
            /p:UUPMediaTargetFramework=net6.0 \
            /p:LangVersion=latest \
            /p:SelfContained=true \
            /p:PublishSingleFile=true \
            /p:PublishTrimmed=false \
            /p:PublishDir="${out}/"
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
