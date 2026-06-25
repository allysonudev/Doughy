fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Capture localized App Store screenshots, then add device frames + captions

### ios frame_all_locales

```sh
[bundle exec] fastlane ios frame_all_locales
```

Frame + caption already-captured screenshots (no recapture). Re-run after editing captions.

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Upload the latest localized screenshots to App Store Connect for version 1.1

### ios upload_metadata

```sh
[bundle exec] fastlane ios upload_metadata
```

Upload localized App Store metadata only for version 1.1

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
