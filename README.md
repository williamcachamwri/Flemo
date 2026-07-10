# Flemo

<p align="center">
  <img src="docs/assets/flemo-logo.png" width="120" alt="Flemo">
</p>

<p align="center">
  <b>Inline emoji that follows your typing.</b><br>
  A fast, polished inline emoji picker for macOS.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-0A84FF?style=flat-square&logo=apple&logoColor=white" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5.9-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/Updates-Sparkle-18A058?style=flat-square" alt="Sparkle">
  <img src="https://img.shields.io/github/v/release/williamcachamwri/Flemo?style=flat-square&label=release" alt="Latest release">
  <img src="https://img.shields.io/github/actions/workflow/status/williamcachamwri/Flemo/build.yml?style=flat-square&branch=main" alt="Build">
  <br>
  <a href="https://github.com/williamcachamwri/Flemo/releases/latest">Download</a>
  ·
  <a href="#install">Install</a>
  ·
  <a href="#build">Build</a>
  ·
  <a href="docs/SPARKLE.md">Updates</a>
</p>

<p align="center">
  <img src="docs/assets/flemo-demo.gif" width="720" alt="Flemo demo">
</p>

---

## Features

- **Inline suggestions** — Type a trigger character, pick from a compact animated strip right at your cursor.
- **Emoji board** — Full category grid with live keyword search.
- **Skin tone preferences** — Unified preference collapses duplicate person emoji variants.
- **Smart ranking** — Frequency tracker moves your most-used emoji to the top.
- **Site & app rules** — Suppress Flemo on specific domains or in specific apps.
- **Customisation** — Choose from 6 popup themes, 2 layouts, and adjustable trigger length.

## Install

Download the latest `Flemo-Release-vX.Y.Z.zip` from [Releases](https://github.com/williamcachamwri/Flemo/releases/latest), unzip, and drag `Flemo.app` into `/Applications`.

Since the app is ad-hoc signed, clear the quarantine flag:

```sh
sudo xattr -dr com.apple.quarantine /Applications/Flemo.app
open /Applications/Flemo.app
```

## Permissions

Flemo needs three permissions to work:

| Permission | Purpose |
|---|---|
| **Accessibility** | Read text and cursor position for inline suggestions |
| **Input Monitoring** | Detect keyboard events (trigger keys, arrow navigation) |
| **Automation** | Read browser URLs so site rules can suppress suggestions |

Grant them in **System Settings → Privacy & Security**. Flemo will prompt you on first launch.

## Build

```sh
swift build -c debug --product Flemo
```

Create a local app bundle:

```sh
BUILD_CONFIGURATION=debug SIGN_IDENTITY=- ./build-app.sh
```

| Variable | Default | Description |
|---|---|---|
| `BUILD_CONFIGURATION` | `debug` | `debug` or `release` |
| `SIGN_IDENTITY` | `-` (ad-hoc) | Code-signing identity |
| `INSTALL_APP` | `1` | Set to `0` to skip copying into `/Applications` |

## Update Channels

Flemo uses [Sparkle 2](https://sparkle-project.org) for automatic updates with separate channels:

| Channel | Bundle | Appcast |
|---|---|---|
| **Release** | `Flemo.app` | [`appcast.xml`](https://williamcachamwri.github.io/Flemo/appcast.xml) |
| **Debug** | `Flemo Debug.app` | [`debug-appcast.xml`](https://williamcachamwri.github.io/Flemo/debug-appcast.xml) |

See [docs/SPARKLE.md](docs/SPARKLE.md) for signing setup and custom feed configuration.

## CI

GitHub Actions builds both Debug and Release `.app` bundles for every push and pull request. Tag pushes (`v*`) create a [GitHub Release](https://github.com/williamcachamwri/Flemo/releases) with zipped bundles, signed appcasts, and auto-generated release notes.

## Requirements

- macOS 14 Sonoma or newer
- Swift 5.9+
- Xcode 15+ (to build from source)
