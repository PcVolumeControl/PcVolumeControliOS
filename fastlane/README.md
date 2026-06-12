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

### ios build

```sh
[bundle exec] fastlane ios build
```

Build the app without running tests

### ios test

```sh
[bundle exec] fastlane ios test
```

Run unit tests

### ios periphery

```sh
[bundle exec] fastlane ios periphery
```

Scan for unused (dead) code with periphery

### ios build_release

```sh
[bundle exec] fastlane ios build_release
```

Build release IPA

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Capture App Store screenshots

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Upload to TestFlight

### ios deploy

```sh
[bundle exec] fastlane ios deploy
```

Build, screenshot, and upload to App Store Connect

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
