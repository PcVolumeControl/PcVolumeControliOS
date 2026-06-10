# Contributing to PCVolumeControl

Thanks for contributing! This guide covers the local development workflow.

## Prerequisites

- Xcode 16+ with the iOS 17+ SDK
- [Homebrew](https://brew.sh)

## Building and Running

```sh
open PcVolumeControl.xcodeproj
```

Select a simulator or device and build/run with the Xcode run button (`Cmd+R`).

## Running Tests

```sh
xcodebuild test -scheme PcVolumeControl \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.0'
```

## Dead Code Analysis

We use [periphery](https://github.com/peripheryapp/periphery) to find unused code.
Run a scan before opening a pull request and resolve anything it reports.

1. Install (one-time):

   ```sh
   brew install peripheryapp/periphery/periphery
   ```

2. From the repository root, run:

   ```sh
   periphery scan
   ```

`periphery scan` reads the committed `.periphery.yml`; a clean run prints
`No unused code detected.`.

Alternatively, run the same check CI runs via fastlane:

```sh
bundle exec fastlane periphery
```

The `periphery` lane runs `periphery scan --strict`, so it exits non-zero when
unused code is found. CI (`.github/workflows/ci.yml`) runs this lane on every push
and pull request, so a scan failure will fail the build.

### Handling findings

Prefer deleting genuinely unused code. When periphery flags code that is *not*
actually dead, do not silence it blindly:

- Code reachable only through reflection, SwiftUI SPI, or the wire protocol can be
  retained via `.periphery.yml` settings (e.g. `retain_codable_properties`) or a
  targeted `// periphery:ignore` comment with an explanatory note.
- Vendored or generated files (e.g. fastlane's `SnapshotHelper.swift`) and
  intentional scaffolding are listed under `report_exclude` in `.periphery.yml`.

Always add a comment explaining why an exclusion or ignore is justified.

### Troubleshooting

If periphery fails with `Scheme 'PcVolumeControl' does not exist`, you likely have
a stale per-user scheme shadowing the shared one. Remove it (it is git-ignored and
Xcode regenerates it):

```sh
rm PcVolumeControl.xcodeproj/xcuserdata/*.xcuserdatad/xcschemes/PcVolumeControl.xcscheme
```

## Code Style

- Target iOS 17+ with SwiftUI and the MVVM pattern.
- NEVER use emojis in code, including comments and log output.
</content>
</invoke>
