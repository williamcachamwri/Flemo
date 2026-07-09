# Sparkle Updates

Flemo uses Sparkle 2 for non-App-Store updates.

## Channels

`build-app.sh` creates separate apps so Debug and Release never share the same Sparkle identity:

- Release: `Flemo.app`, bundle ID `com.flemo.app`, default feed `https://williamcachamwri.github.io/Flemo/appcast.xml`
- Debug: `Flemo Debug.app`, bundle ID `com.flemo.debug`, default feed `https://williamcachamwri.github.io/Flemo/debug-appcast.xml`

The appcasts are served from the repo root via GitHub Pages. Update archives themselves are downloaded from GitHub Release assets, so the feed URL and the enclosure URL point to different hosts on purpose.

Override feed URLs with:

```sh
FLEMO_RELEASE_APPCAST_URL="https://your-domain.example/flemo/appcast.xml"
FLEMO_DEBUG_APPCAST_URL="https://your-domain.example/flemo/debug-appcast.xml"
```

On tag pushes, CI signs the update archives with `sign_update` (EdDSA), embeds `sparkle:edSignature` + the real archive length into both appcasts, uploads the zips and appcasts to the GitHub Release, and commits the signed appcasts back to the repo root (served by GitHub Pages).

## Keys

Generate Sparkle EdDSA keys with Sparkle's `generate_keys` tool (separate accounts per channel: `flemo-release`, `flemo-debug`). Add these GitHub secrets:

- `FLEMO_RELEASE_SPARKLE_PUBLIC_KEY` / `FLEMO_DEBUG_SPARKLE_PUBLIC_KEY` — embedded into each app's `Info.plist` as `SUPublicEDKey` at build time.
- `FLEMO_RELEASE_SPARKLE_PRIVATE_KEY` / `FLEMO_DEBUG_SPARKLE_PRIVATE_KEY` — used by CI to sign the appcasts. Never commit these.

## Local Builds

```sh
BUILD_CONFIGURATION=debug SIGN_IDENTITY=- ./build-app.sh
BUILD_CONFIGURATION=release SIGN_IDENTITY=- ./build-app.sh
```

Set `INSTALL_APP=0` to build without copying into `/Applications`.
