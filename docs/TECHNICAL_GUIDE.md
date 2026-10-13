# UUP Media Creator — Technical Guide

> 🌐 English · [Español](./GUIA_TECNICA.md)

This document explains, in depth, how the UUP Media Creator toolset works internally: how it talks to Microsoft's Windows Update (UUP) servers, how it turns a downloaded file set into a bootable ISO, and how to build, run and verify it on Linux, Windows and macOS.

- [1. Overview](#1-overview)
- [2. Architecture and components](#2-architecture-and-components)
- [3. How downloading works](#3-how-downloading-works)
- [4. How media conversion works](#4-how-media-conversion-works)
- [5. CLI reference](#5-cli-reference)
- [6. Building and publishing](#6-building-and-publishing)
- [7. Platform support](#7-platform-support)
- [8. Verification](#8-verification)
- [9. Troubleshooting](#9-troubleshooting)
- [10. References](#10-references)

---

## 1. Overview

UUP Media Creator is a set of .NET 10 command line tools:

| Tool | Assembly | Purpose |
|------|----------|---------|
| `UUPDownload` | `src/Applications/UUPDownload` | Scans, queries and downloads file sets from the Microsoft Unified Update Platform (UUP) |
| `UUPMediaConverter` | `src/Applications/UUPMediaConverter` | Converts a downloaded UUP set for Windows Desktop into a bootable ISO |

Both targets are **cross-platform** (`net10.0`, RIDs include `win-*`, `linux-*`, `osx-*`). The Linux build uses the **wimlib** native library (`libwim.so`, bundled via the `ManagedWimLib` NuGet package) and the **`mkisofs`/`genisoimage`** external tool for ISO mastering, while Windows uses WIMGAPI/DISM and the bundled `cdimage.exe`.

---

## 2. Architecture and components

```
UUPMediaCreator-lin/
├── src/
│   ├── Applications/
│   │   ├── UUPDownload/                  # CLI: request-download, replay-download, get-builds
│   │   ├── UUPMediaConverter/            # CLI: desktop-convert
│   │   ├── UUPSort/                      # post-processing utility (Windows-only TFM)
│   │   └── Playground/                   # dev sandbox (Windows-only TFM)
│   ├── UnifiedUpdatePlatform.Services.WindowsUpdate/     # CTAC + FE3 SOAP client + ESRP + auth (MBI)
│   ├── UnifiedUpdatePlatform.Services.WindowsUpdate.Downloads/  # file downloader + verification + replay
│   ├── UnifiedUpdatePlatform.Services.Composition.Database/     # CompDB (.xml.cab) parsing
│   ├── UnifiedUpdatePlatform.Media.Creator.Planning/            # edition/language planning
│   ├── UnifiedUpdatePlatform.Media.Creator/                     # ISO/media building, DISM ops, CDImage wrapper
│   ├── UnifiedUpdatePlatform.Imaging/                           # WIMGAPI w/ wimlib fallback (Linux/macOS)
│   ├── Cabinet/                          # CAB/LZX decompression (Cabinet.Shared)
│   ├── TempManager/                      # cross-platform temp-dir manager
│   ├── CompDB/                           # composition-database models & services
│   ├── VirtualHardDiskLib/               # VHD mounting — WINDOWS ONLY (virtdisk.dll)
│   └── Windows.Internal.Flighting/       # WinRT flighting probe (Windows-only, dev only)
└── thirdparty/
    ├── Microsoft.Wim/                    # WIMGAPI P/Invoke wrapper (used on Windows)
    ├── Microsoft.Dism/                   # DISM API P/Invoke wrapper (used on Windows)
    └── Privileges/                       # Windows privilege elevation helper
```

Key notes:

- **`TempManager`** (`src/TempManager/TempManager.cs`) resolves the temporary directory. On Windows this is the `TEMP` environment variable; on Linux/macOS `TEMP` is usually unset, so it falls back to `Path.GetTempPath()` (which honors `TMPDIR`).
- **`VirtualHardDiskLib`** is Windows-only (P/Invokes `virtdisk.dll`/`kernel32.dll`). It is only reached by the *multi-edition*, *upgrade* and *AppX slipstream* code paths, **not** by the single base-edition ISO path. This is why "all editions" conversion is marked as not supported on Linux.
- **`thirdparty/Microsoft.Wim`** compiles everywhere but only *works* on Windows (loads `WimgApi.dll`); on Linux/macOS the imaging layer (`src/UnifiedUpdatePlatform.Imaging/WimLibImaging.cs`) checks `RuntimeInformation.IsOSPlatform` and uses **wimlib** instead.

---

## 3. How downloading works

### 3.1 The Windows Update "impersonation"

The downloader never asks Microsoft "give me Windows build X". Instead it impersonates an actual Windows client device and asks "what do you have for a device like me?". This is what the famous parameters mean:

- `-s / --reporting-sku` — the SKU/product to report (`OSSkuId` enum, see `CTAC.cs:53-258`).
- `-v / --reporting-version` — the OS version to claim (`10.0.x.y`).
- `-t / --machine-type` — the architecture (`MachineType` enum: `x86`, `amd64`, `arm64`, …).
- `-r / --flight-ring` — servicing ring (`Retail`, `External`, `Internal`, …).
- `-c / --current-branch` — release branch (`vb_release`, `ni_release`, `rs5_release`, …).
- `-b / --flighting-branch-name` — insider branch (`Retail`, `ReleasePreview`, `Beta`, `Dev`, `CanaryChannel`).
- `-y / --sync-current-version-only` — pin the exact current version instead of getting newer ones.

All of these are assembled into a **CTAC** (Client Targeting Attribute Context) in `src/UnifiedUpdatePlatform.Services.WindowsUpdate/CTAC.cs`. For each SKU a set of attributes is sent to Windows Update:

```
E:...&FlightRing=...&DeviceFamily=Windows.Desktop&OSSkuId=...&CurrentBranch=...&OSVersion=...&OSArchitecture=AMD64&...
```

and a *product* string is built at `CTAC.cs:522-526`:

```
PN=Client.OS.rs2.amd64&Branch=vb_release&PrimaryOSProduct=1&Repairable=1&V=10.0.19041.200;
```

The SKU → device family mapping is hard-coded (`CTAC.cs:317-378`): Desktop → `Windows.Desktop`, Server → `Windows.Server`, `IoTUAP` → `Windows.IoTUAP`, `MobileCore` → `Windows.Mobile`, `Holographic` → `Windows.Holographic`, `Lite`/`Andromeda`/`HubOS` → `Windows.Core` (10X/WCOS), `PPIPro` → `Windows.Team`.

### 3.2 The FE3 protocol

All requests go to the FE3 endpoint:

- Endpoint: `https://fe3cr.delivery.mp.microsoft.com/ClientWebService/client.asmx` (`Constants.cs:28`), secured variant under `/secured`.
- SOAP namespace: `http://www.microsoft.com/SoftwareDistribution/Server/ClientWebService`.
- Protocol version: `2.50`.
- SOAP actions: `GetCookie`, `SyncUpdates`, `GetExtendedUpdateInfo`, `GetExtendedUpdateInfo2` (`FE3Handler.cs`).
- Update filter: always `ProductRelease` (`FE3Handler.cs:545-550`).

Optionally, an Insider (MSA) authorization token can be obtained with `-m`/`-p` through `MBIHelper.cs` (`login.live.com` OAuth, scope `service::dcat.update.microsoft.com::MBI_SSL`).

### 3.3 Enumerating available builds

`UUPDownload get-builds` iterates a hard-coded set of CTACs (one per ring, `RingCheck.cs:36-51`) and prints the newest build offered for each ring. The presets cover Windows 10 1709 (RS3) through current dev/canary builds, so you can confirm that **old builds are still being served**:

```
"Retail (RS3)"[0]="10.0.16299.15 (rs3_release.170928-1534)"
"Retail (RS4)"[0]="10.0.17134.1 (rs4_release.180410-1804)"
"Retail (RS5)"[0]="10.0.17763.1217 (rs5_release_svc_prod1.200505-1609)"
"Retail (TI)"[0]="10.0.18362.836 (19h1_release_svc_prod1.200505-1604)"
"Retail"[0]="10.0.19045.6456 (vb_release_svc_prod1.251010-0328)"
"Dev"[0]="10.0.26340.9616 (ge_prerelease_im.260929-2016)"
```

### 3.4 Downloading a file set

`UUPDownload request-download`:

1. Builds the CTAC and calls `SyncUpdates` to discover applicable updates.
2. Selects the UUP update (`FileExchangeV3UpdateFilter.ProductRelease`).
3. Downloads the metadata (CompDB `.xml.cab` files).
4. **Plans the file list** for the requested edition/language (`CompDB` → `ConversionPlanBuilder.GetTargetedPlan`). If `-e`/`-l` are given, only the payloads for that edition/language are kept (`DownloadHelpers.cs`).
5. **Downloads each payload** (`HttpDownloader`), optionally decrypting **ESRP** (Encrypted Service Release Payload) blobs and verifying SHA-256 hashes.
6. Writes a `*.uupmcreplay` metadata file for the `replay-download` verb.

The per-file lines printed by the tool use this format:

```
[HH:mm:ss][n/N][E:<errors>][C|D|V|F] <payload> (<size>)
```

where `C` = completed/verified, `D` = downloading, `V` = verified, `F` = failed.

---

## 4. How media conversion works

`UUPMediaConverter desktop-convert` (entry point `DesktopConvert.cs` → `MediaCreator.CreateISOMedia`):

1. **Parse the UUP set** — `FileLocator.GetCompDBsFromUUPFiles` opens the CompDB `.xml.cab` files and builds a temporary working area (`TempManager`).
2. **Plan editions** — `ConversionPlanBuilder.GetTargetedPlan` produces `EditionTarget`s for the requested language. With `-e` only that edition is built (this is the path supported on Linux); without it, "all editions" is attempted, which on Linux is **not** supported (needs VHD/DISM).
3. **Build setup media** — `SetupMediaCreator.CreateSetupMedia` copies the boot files, `boot.sdi`, `winre.wim`, language packs and OS binaries into a `MediaRoot`, and rebuilds the Windows RE image (this is where wimlib is used on Linux for `wimlib-imagex`-style operations).
4. **Build `install.wim`/`install.esd`** — `HandleEditionPlan` captures the base edition into `sources\install.wim` (or `.esd` when `-c LZMS`).
   - **Windows:** WIMGAPI (`WimgApi.dll`) for WIM operations.
   - **Linux/macOS:** wimlib (`libwim.so`/`.dylib`).
5. **Master the ISO** — `CDImageWrapper.GenerateISOImage`:
   - **Windows:** bundled `cdimage.exe` from `CDImage/` with `-bootdata` for eltorito + UDF.
   - **Linux/macOS:** spawns **`mkisofs`** (from `genisoimage`/`cdrtools`) with `--no-emul-boot --eltorito-alt-boot --udf` and the matching `etfsboot.com`/`efisys.bin` boot files (`CDImageWrapper.cs:86-128`).

> **Note:** the non-Windows branch does not validate that `mkisofs` exists on PATH; the process simply fails if it is missing. Install `genisoimage` on Debian/Ubuntu (`apt-get install genisoimage`) or `cdrtools` on macOS (`brew install cdrtools`).

### Platform capabilities

| Operation | Windows | Linux/macOS |
|-----------|---------|-------------|
| Download UUP, verify, replay, decrypt ESRP | ✅ | ✅ |
| Base-edition ISO (one edition) | ✅ | ✅ |
| All-editions ISO, upgrades, AppX slipstream | ✅ | ❌ (needs VHD + DISM, Windows-only) |
| `--no-key-prompt` (silent boot prompt) | ✅ | ✅ |

---

## 5. CLI reference

### `UUPDownload`

```
UUPDownload request-download (default)
  -s, --reporting-sku        SKU to report (OSSkuId). e.g. Professional        [required]
  -v, --reporting-version    OS version to claim. e.g. 10.0.19041.200          [required]
  -t, --machine-type         Architecture (MachineType). e.g. amd64            [required]
  -r, --flight-ring          Ring. e.g. Retail / External / Internal           [required]
  -c, --current-branch       Branch. e.g. vb_release / ni_release              [required]
  -b, --flighting-branch-name  Retail | ReleasePreview | Beta | Dev | CanaryChannel
  -y, --sync-current-version-only  pin exact current version
  -a, --branch-readiness-level     (default CB)
  -o, --output-folder             output directory (default .)
  -e, --edition                   edition filter (with -l)
  -l, --language                  language filter (with -e)
  -z, --releasetype               (default Production)
  -n, --contenttype               (default Mainline)
  -m, --mail / -p, --password     Insider (MSA) credentials (optional)

UUPDownload replay-download
  -r, --replay-metadata   *.uupmcreplay file [required]
  -t, --machine-type      [required]
  -o, --output-folder     (default .)
  -e, --edition / -l, --language
  --fixup Appx            appx fixup
  --appxroot / --cabsroot

UUPDownload get-builds
  -s, --reporting-sku     [required]
  -t, --machine-type      [required]
  -m / -p                 Insider credentials (optional)
  --preview-targeting-attribute   filter by ring name (optional)
```

### `UUPMediaConverter`

```
UUPMediaConverter desktop-convert
  -u, --uup-path           path to the downloaded UUP files            [required]
  -i, --iso-path           destination ISO path                        [required]
  -l, --language-code      language to build, e.g. en-US               [required]
  -e, --edition            edition to build (omit = all editions)
  -t, --temp-path          temp dir (defaults to %TEMP% / system temp)
  -c, --compression-format XPRESS | LZX | LZMS   (default LZX)
  --no-key-prompt          use silent efisys/cdboot implementation
```

---

## 6. Building and publishing

Prerequisites: [.NET 10 SDK](https://dotnet.microsoft.com/download), and for ISO creation `genisoimage` (Linux) / `cdrtools` (macOS).

```bash
# Build (Linux/macOS)
dotnet build src/Applications/UUPDownload/UUPDownload.csproj -c Release
dotnet build src/Applications/UUPMediaConverter/UUPMediaConverter.csproj -c Release

# Publish single-file for Linux
./publish_linux.sh            # linux-x64
./publish_linux.sh arm64      # linux-arm64
```

The whole `.sln` includes Windows-only projects (`UUPSort`, `Playground`, `Windows.Internal.Flighting`) targeting `net10.0-windows`; build the two CLI projects individually (as above) or via the CI matrix, which publishes the CLIs for `win-*`, `linux-*` and `osx-*` RIDs.

---

## 7. Platform support

See the matrix in the [README](../README.md#supported-features-by-os). Summary:

- **Downloading** (all verbs) works on Windows, Linux and macOS.
- **Base-edition ISO conversion** works on all three (mkisofs on Linux/macOS, cdimage on Windows).
- **All-editions/upgrade/AppX** flows are Windows-only (VHD + DISM).
- `UUPSort`, `Playground`, `Windows.Internal.Flighting` are Windows-only dev utilities, not part of the released CLIs.

---

## 8. Verification

Verified on **Linux (Ubuntu 26.04, x86_64, .NET SDK 10.0.112)**:

| Test | Result |
|------|--------|
| `dotnet build` for both CLIs (`net10.0`, Release) | ✅ 0 errors |
| `UUPDownload --help`, `UUPMediaConverter --help` | ✅ |
| `UUPDownload get-builds -s Professional -t amd64` — reports builds from **Windows 10 1709 (RS3)** up to current Dev/Canary | ✅ |
| `UUPDownload request-download` of **Windows 10 1809 (RS5)** (`rs5_release`, `-y`, `-e Professional -l en-US`) — 78 payloads, multi-GB set downloaded, hashes verified | ✅ |
| `UUPMediaConverter desktop-convert` → ISO via wimlib + mkisofs | ✅ Windows 10 1809 (RS5) → 4,2 GB bootable ISO (`CPRA_X64FRE_EN-US_DV9`, El-Torito no-emulation, 945 files / 84 dirs) |

Note: a very old build can stop being served by Microsoft at any time (Microsoft expires/retires WU content); the tool surfaces this as no available payloads, not as an error in the tool.

---

## 9. Troubleshooting

| Symptom | Likely cause / fix |
|---------|--------------------|
| "The specified temporary directory cannot be accessed or does not exist." (Linux) | Fixed in this fork: no `TEMP` needed anymore, falls back to `/tmp` (honors `TMPDIR`). Old builds without the fix need `-t /path` or `TEMP` set. |
| "mkisofs: command not found" | Install `genisoimage` (Debian/Ubuntu) / `cdrtools` (macOS). |
| "Disk quota exceeded"/`ENOSPC` while converting | The default temp dir on Linux is `/tmp` (often a small RAM disk, e.g. tmpfs). Pass `-t` pointing to a directory on a large filesystem (a Windows 10 conversion needs several GB). |
| ISO progress percentages above 100% (`[CreatingISO][9997%]`) | Cosmetic: mkisofs reports per-file percentages; the ISO is still created correctly and ends with `[Done]`. |
| `DllNotFoundException: WimgApi.dll` on Linux | Unusual on the normal path — Linux uses wimlib. Make sure `runtimes/linux-x64/native/libwim.so` is next to the binaries (it is in published output). |
| `PlatformNotSupportedException` from `WimLibImaging` | `libwim.so` for your architecture is missing from the output. |
| `virtdisk.dll`/`DISM` errors on Linux | You requested a multi-edition/upgrade conversion. Not supported on Linux; use a single base edition (`-e`). |
| Build fails on whole `.sln` in Linux | Expected: `UUPSort`/`Playground`/`Flighting` are Windows-only. Build the two CLI projects. |
| No payloads returned for a very old build | Microsoft no longer serves that build; try a nearby version or check `get-builds`. |

---

## 10. References

- [Microsoft Windows Update (FE3) protocol — old documentation references](https://github.com/gus33000/UUPMediaCreator)
- [Microsoft — End of support for Windows](https://www.microsoft.com/en-us/windows/end-of-support)
- [Microsoft — Windows 10 Consumer ESU](https://www.microsoft.com/en-us/windows/extended-security-updates)
- [Microsoft Tech Community — Prepare for Windows Update certificate rotation in 2027](https://techcommunity.microsoft.com/blog/windows-itpro-blog/prepare-for-windows-update-certificate-rotation-in-2027/4562463)