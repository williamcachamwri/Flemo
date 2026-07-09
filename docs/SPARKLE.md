# Sparkle Updates

Flemo uses Sparkle 2 for non-App-Store updates.

## Channels

`build-app.sh` creates separate apps so Debug and Release never share the same Sparkle identity:

- Release: `Flemo.app`, bundle ID `com.flemo.app`, default feed `https://example.com/flemo/appcast.xml`
- Debug: `Flemo Debug.app`, bundle ID `com.flemo.debug`, default feed `https://example.com/flemo/debug/appcast.xml`

Override feed URLs with:

```sh
FLEMO_RELEASE_APPCAST_URL="https://example.com/flemo/appcast.xml"
FLEMO_DEBUG_APPCAST_URL="https://example.com/flemo/debug/appcast.xml"
```

## Keys

Generate Sparkle EdDSA keys with Sparkle's `generate_keys` tool. Put the public keys in GitHub secrets:

- `FLEMO_RELEASE_SPARKLE_PUBLIC_KEY`
- `FLEMO_DEBUG_SPARKLE_PUBLIC_KEY`

Keep the private keys out of the repo. Use them only when signing release archives/appcasts.

## Local Builds

```sh
BUILD_CONFIGURATION=debug SIGN_IDENTITY=- ./build-app.sh
BUILD_CONFIGURATION=release SIGN_IDENTITY=- ./build-app.sh
```

Set `INSTALL_APP=0` to build without copying into `/Applications`.
