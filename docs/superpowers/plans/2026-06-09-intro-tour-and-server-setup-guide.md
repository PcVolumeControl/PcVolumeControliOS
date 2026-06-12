# Intro Tour and Server Setup Guide Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a one-time 3-page intro tour on first launch and a persistent, always-visible Windows server setup guide reachable from the connect screen and Settings.

**Architecture:** Two new SwiftUI views (`IntroTourView`, `ServerSetupGuideView`) plus a tiny pure gate function (`IntroTourGate`) that decides whether the tour auto-shows (honors a `hasSeenIntroTour` UserDefaults flag and suppresses the tour under fastlane's `--screenshotMode`). MainView gains a pinned footer button and a `.fullScreenCover`; SettingsView gains a Help section. Spec: `docs/superpowers/specs/2026-06-09-intro-tour-and-server-setup-guide-design.md`.

**Tech Stack:** SwiftUI (iOS 17+), XCTest, UserDefaults via `@AppStorage`.

**Project facts the engineer must know:**

- The `views/`, `models/`, and test folders are Xcode *synchronized folder groups*: creating a `.swift` file on disk inside them automatically adds it to the target. Do NOT edit `project.pbxproj`.
- Build command: `xcodebuild build -scheme PcVolumeControl -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.0' -quiet` — expect `** BUILD SUCCEEDED **` (warnings OK).
- Full test command: `xcodebuild test -scheme PcVolumeControl -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.0' -quiet`
- NEVER use emojis anywhere in code, including comments.
- Existing styling helpers: `Color.almostBlack`, `Color.sliderPink` (accent pink), `Color.pcvcBlue` (in `views/UIStyling.swift`). The app is dark-themed.
- `UserDefaultsKeys` struct lives at the top of `PcVolumeControl/views/SettingsView.swift`.
- Run all commands from the repo root: `/Users/bill/src/pcvolumecontrol/PcVolumeControliOS`.

---

### Task 1: ServerSetupGuideView

**Files:**
- Create: `PcVolumeControl/views/ServerSetupGuideView.swift`

- [ ] **Step 1: Create the view file**

Create `PcVolumeControl/views/ServerSetupGuideView.swift` with exactly:

```swift
//
//  ServerSetupGuideView.swift
//  PcVolumeControl
//
//  Step-by-step guide for installing the Windows companion server.
//  Designed to work both pushed onto a NavigationStack (intro tour,
//  Settings) and wrapped in a sheet (connect screen footer).
//

import SwiftUI

// Single source of truth for the Windows server download location.
enum ServerDownload {
    static let releasesURL = URL(string: "https://github.com/PcVolumeControl/PcVolumeControlWindows/releases/latest")!
}

struct ServerSetupGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("PcVolumeControl needs a small, free server running on your Windows PC. Set it up once and this app can find it automatically.")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                SetupStepRow(number: 1, title: "Download the server") {
                    Text("On your Windows PC, download the latest installer from GitHub.")
                    Link(destination: ServerDownload.releasesURL) {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                            Text("PcVolumeControlWindows releases")
                        }
                        .font(.footnote)
                        .foregroundColor(.sliderPink)
                    }
                }

                SetupStepRow(number: 2, title: "Install and run it") {
                    Text("Run the installer, then start the server. If Windows Firewall asks, click Allow so the server can accept connections on private networks.")
                }

                SetupStepRow(number: 3, title: "Find the address") {
                    Text("The server window shows your PC's IP address and port. The default port is 3000.")
                }

                SetupStepRow(number: 4, title: "Connect from this app") {
                    Text("With your phone on the same Wi-Fi network as the PC, your computer usually appears in the server list automatically. Otherwise, type the IP address and port manually.")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Trouble connecting?")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("Make sure the phone and PC are on the same network, the server is allowed through Windows Firewall, and no VPN is active on either device. VPNs often block local discovery.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding(.top, 8)
            }
            .padding(20)
            .readableContentWidth()
        }
        .background(Color.almostBlack.ignoresSafeArea())
        .navigationTitle("Set Up Your PC")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }
}

// One numbered step card: pink number badge, title, and free-form body
// content (text plus optional links).
private struct SetupStepRow<Content: View>: View {
    let number: Int
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.sliderPink))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                content
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
    }
}

#Preview {
    NavigationStack {
        ServerSetupGuideView()
    }
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme PcVolumeControl -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.0' -quiet`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add PcVolumeControl/views/ServerSetupGuideView.swift
git commit -m "feat: add Windows server setup guide view"
```

---

### Task 2: IntroTourGate (TDD)

The gate is a pure function so the first-launch decision is unit-testable without UI.

**Files:**
- Create: `PcVolumeControlTests/IntroTourGateTests.swift`
- Create: `PcVolumeControl/views/IntroTourGate.swift`

- [ ] **Step 1: Write the failing tests**

Create `PcVolumeControlTests/IntroTourGateTests.swift` with exactly:

```swift
//
//  IntroTourGateTests.swift
//  PcVolumeControlTests
//

import XCTest
@testable import PcVolumeControl

final class IntroTourGateTests: XCTestCase {

    func testShowsTourOnFirstLaunch() {
        XCTAssertTrue(IntroTourGate.shouldShowTour(hasSeenTour: false, arguments: []))
    }

    func testDoesNotShowTourWhenAlreadySeen() {
        XCTAssertFalse(IntroTourGate.shouldShowTour(hasSeenTour: true, arguments: []))
    }

    func testScreenshotModeSuppressesTour() {
        XCTAssertFalse(IntroTourGate.shouldShowTour(hasSeenTour: false, arguments: ["--screenshotMode"]))
    }

    func testScreenshotModeWithOtherArgumentsStillSuppresses() {
        XCTAssertFalse(IntroTourGate.shouldShowTour(
            hasSeenTour: false,
            arguments: ["--screenshotMode", "--mockConnected"]
        ))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -scheme PcVolumeControl -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.0' -only-testing:PcVolumeControlTests/IntroTourGateTests -quiet`
Expected: FAIL — compile error `cannot find 'IntroTourGate' in scope`

- [ ] **Step 3: Write the implementation**

Create `PcVolumeControl/views/IntroTourGate.swift` with exactly:

```swift
//
//  IntroTourGate.swift
//  PcVolumeControl
//
//  Decides whether the first-launch intro tour should auto-present.
//

import Foundation

enum IntroTourGate {
    // Fastlane snapshot launches with --screenshotMode and needs
    // deterministic screens, so the tour never auto-shows there.
    static func shouldShowTour(
        hasSeenTour: Bool,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        if arguments.contains("--screenshotMode") { return false }
        return !hasSeenTour
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -scheme PcVolumeControl -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.0' -only-testing:PcVolumeControlTests/IntroTourGateTests -quiet`
Expected: PASS — `Test Suite 'IntroTourGateTests' passed`, 4 tests, 0 failures

- [ ] **Step 5: Commit**

```bash
git add PcVolumeControlTests/IntroTourGateTests.swift PcVolumeControl/views/IntroTourGate.swift
git commit -m "feat: add testable first-launch gate for intro tour"
```

---

### Task 3: IntroTourView

**Files:**
- Create: `PcVolumeControl/views/IntroTourView.swift`

- [ ] **Step 1: Create the view file**

Create `PcVolumeControl/views/IntroTourView.swift` with exactly:

```swift
//
//  IntroTourView.swift
//  PcVolumeControl
//
//  Three-page first-launch welcome tour. Page 2 pushes the server
//  setup guide. Skip and Get Started both call onFinish; the caller
//  is responsible for persisting hasSeenIntroTour and dismissing.
//

import SwiftUI

struct IntroTourView: View {
    var onFinish: () -> Void

    @State private var page = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.almostBlack.ignoresSafeArea()

                TabView(selection: $page) {
                    whatItIsPage.tag(0)
                    serverPage.tag(1)
                    connectPage.tag(2)
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") {
                        onFinish()
                    }
                    .foregroundColor(.gray)
                    .accessibilityHint("Closes the intro tour")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var whatItIsPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image("PCVCLogo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .foregroundStyle(.white)
            Text("Control your PC's audio from your phone")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("Adjust the volume of every application on your Windows PC remotely. Turn the game down without leaving voice chat behind.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var serverPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "desktopcomputer")
                .font(.system(size: 64))
                .foregroundColor(.sliderPink)
                .accessibilityHidden(true)
            Text("Your PC needs the free server")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("This app talks to the PcVolumeControl server, a small program that runs on your Windows PC.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            NavigationLink {
                ServerSetupGuideView()
            } label: {
                Text("Show me how to set it up")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.sliderPink))
            }
            Text("You can also do this later from the connection screen.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var connectPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "wifi")
                .font(.system(size: 64))
                .foregroundColor(.green)
                .accessibilityHidden(true)
            Text("Connecting is automatic")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("On the same Wi-Fi network, your PC appears in the server list with a green Wi-Fi badge. Tap it to connect, or enter an IP address and port manually.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button {
                onFinish()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.sliderPink))
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    IntroTourView {
    }
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme PcVolumeControl -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.0' -quiet`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add PcVolumeControl/views/IntroTourView.swift
git commit -m "feat: add three-page first-launch intro tour view"
```

---

### Task 4: MainView and UserDefaultsKeys integration

**Files:**
- Modify: `PcVolumeControl/views/SettingsView.swift:10-13` (UserDefaultsKeys struct)
- Modify: `PcVolumeControl/views/MainView.swift` (state, footer, presentation modifiers, onAppear)

- [ ] **Step 1: Add the UserDefaults key**

In `PcVolumeControl/views/SettingsView.swift`, change:

```swift
struct UserDefaultsKeys {
    static let preserveSessionOrder = "preserveSessionOrder"
    static let hasSeenChatBalanceInfo = "hasSeenChatBalanceInfo"
}
```

to:

```swift
struct UserDefaultsKeys {
    static let preserveSessionOrder = "preserveSessionOrder"
    static let hasSeenChatBalanceInfo = "hasSeenChatBalanceInfo"
    static let hasSeenIntroTour = "hasSeenIntroTour"
}
```

- [ ] **Step 2: Add state to MainView**

In `PcVolumeControl/views/MainView.swift`, after the line `@FocusState private var focusedField: FocusedField?` add:

```swift
    @AppStorage(UserDefaultsKeys.hasSeenIntroTour) private var hasSeenIntroTour = false
    @State private var showIntroTour = false
    @State private var showSetupGuide = false
```

- [ ] **Step 3: Add the pinned footer below the server list**

In MainView's body, the `VStack(spacing: 0)` currently ends with the `List { ... }` block (which closes with `.scrollBounceBehavior(.basedOnSize)`). Immediately after that `.scrollBounceBehavior(.basedOnSize)` line, still inside the VStack, add:

```swift

                    // Persistent path to the server setup guide. Pinned
                    // below the list so a user with an empty server list
                    // always sees it.
                    Button {
                        showSetupGuide = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(.sliderPink)
                            Text("Don't have the PC server yet? Set it up")
                                .foregroundColor(.white)
                        }
                        .font(.footnote)
                        .padding(.vertical, 12)
                    }
                    .accessibilityHint("Opens the Windows server setup guide")
```

- [ ] **Step 4: Add the presentation modifiers**

In MainView, after the existing `.overlay { ... }` modifier (the one showing `ConnectingView()`), add:

```swift
            .sheet(isPresented: $showSetupGuide) {
                NavigationStack {
                    ServerSetupGuideView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    showSetupGuide = false
                                }
                            }
                        }
                }
            }
            .fullScreenCover(isPresented: $showIntroTour) {
                IntroTourView {
                    hasSeenIntroTour = true
                    showIntroTour = false
                }
            }
```

- [ ] **Step 5: Gate the tour in onAppear**

In MainView's `.onAppear { ... }`, add the gate check as the FIRST statement, before the `#if DEBUG` screenshot block (the gate itself returns false under `--screenshotMode`, so screenshot runs are unaffected):

```swift
            .onAppear {
                if IntroTourGate.shouldShowTour(hasSeenTour: hasSeenIntroTour) {
                    showIntroTour = true
                }
                #if DEBUG
                if configureForScreenshotsIfNeeded() { return }
                #endif
                viewModel.loadRecentServers()
                mdnsService.startDiscovery()
            }
```

- [ ] **Step 6: Build and run the full unit test suite**

Run: `xcodebuild test -scheme PcVolumeControl -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.0' -quiet`
Expected: all tests pass, 0 failures

- [ ] **Step 7: Commit**

```bash
git add PcVolumeControl/views/MainView.swift PcVolumeControl/views/SettingsView.swift
git commit -m "feat: show intro tour on first launch and pin setup guide to connect screen"
```

---

### Task 5: Settings Help section

**Files:**
- Modify: `PcVolumeControl/views/SettingsView.swift` (SettingsView struct)

- [ ] **Step 1: Add replay state**

In `SettingsView`, after the line `@AppStorage(UserDefaultsKeys.preserveSessionOrder) private var preserveSessionOrder = true` add:

```swift
    @State private var showIntroTour = false
```

- [ ] **Step 2: Add the Help section**

In SettingsView's `Form`, between the `Section(header: Text("Custom Names")) { ... }` block and the `Section(header: Text("About")) { ... }` block, add:

```swift

                Section(header: Text("Help")) {
                    NavigationLink(destination: ServerSetupGuideView()) {
                        Text("PC Server Setup Guide")
                    }

                    Button("Replay Intro Tour") {
                        showIntroTour = true
                    }
                    .foregroundColor(.white)
                }
```

- [ ] **Step 3: Add the tour presentation**

On SettingsView's `Form` (after the existing `.background(Color.almostBlack.edgesIgnoringSafeArea(.all))` modifier inside the NavigationStack), add:

```swift
            .fullScreenCover(isPresented: $showIntroTour) {
                IntroTourView {
                    showIntroTour = false
                }
            }
```

Note: replay deliberately does NOT touch `hasSeenIntroTour`; the flag was already set on first launch, and replaying is a one-off.

- [ ] **Step 4: Build to verify it compiles**

Run: `xcodebuild build -scheme PcVolumeControl -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.0' -quiet`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add PcVolumeControl/views/SettingsView.swift
git commit -m "feat: add Help section with setup guide and tour replay to settings"
```

---

### Task 6: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full unit test suite**

Run: `xcodebuild test -scheme PcVolumeControl -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.0' -quiet`
Expected: all tests pass, 0 failures

- [ ] **Step 2: Run the dead-code scan**

Run: `periphery scan`
Expected: `No unused code detected.` (all new types are referenced: `ServerSetupGuideView` from MainView/SettingsView/IntroTourView, `IntroTourView` from MainView/SettingsView, `IntroTourGate` from MainView, `ServerDownload` from ServerSetupGuideView)

- [ ] **Step 3: Manual smoke test in the simulator**

1. Reset first-launch state: `xcrun simctl boot "iPhone 17 Pro Max" 2>/dev/null; xcrun simctl uninstall booted moronbros.PcVolumeControl 2>/dev/null` (uninstalling clears UserDefaults; both commands are no-ops if already booted/not installed)
2. Build and run from Xcode (or `xcodebuild build` + `xcrun simctl install/launch`)
3. Verify: tour appears on first launch; swiping reaches all 3 pages; page 2's button pushes the setup guide; Get Started dismisses; relaunching the app does NOT show the tour again
4. Verify: footer button on the connect screen opens the setup guide as a sheet with a working Done button; the GitHub link opens Safari
5. Verify: connect to a server (or use screenshot mock mode), open Settings, and check the Help section's guide link and Replay Intro Tour both work

- [ ] **Step 4: Verify screenshot mode is unaffected**

Run: `bundle exec fastlane snapshot` only if you want full confirmation (slow). Cheaper check: the gate unit test `testScreenshotModeSuppressesTour` already covers the logic, and `configureForScreenshotsIfNeeded()` is untouched.
