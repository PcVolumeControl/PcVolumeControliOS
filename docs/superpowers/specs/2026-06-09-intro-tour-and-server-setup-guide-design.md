# Intro Tour and Server Setup Guide — Design

Date: 2026-06-09
Status: Approved

## Problem

PcVolumeControl is a client app that is useless without its companion Windows
server. New users land on the connect screen with an empty server list and no
explanation of what the app does, that a server is required, or where to get
it. We need:

1. A short first-launch intro/tour explaining how the app works.
2. A persistent entry point on the connect screen that walks users through
   setting up the Windows server.

The server is downloaded from:
https://github.com/PcVolumeControl/PcVolumeControlWindows/releases

## Decisions made during brainstorming

- Tour format: paged welcome sheet (not coach marks). The slider screen
  already has a contextual one-time tip (ChatBalanceInfoOverlay), so paged
  intro + existing contextual tips gives hybrid coverage.
- Setup guide: native in-app step-by-step screen; only the download link
  opens Safari.
- Persistent entry point: pinned footer at the bottom of the connect screen,
  always visible regardless of list length.
- Tour scope: connect basics only, 3 pages. Slider features are discovered
  in context.

## Components

### IntroTourView (new, `views/IntroTourView.swift`)

Full-screen, shown once on first launch. `TabView` with
`.tabViewStyle(.page)`, dark theme matching the app (almostBlack background,
sliderPink accent), page dots, Skip button visible on every page.

Wrapped in its own `NavigationStack` so page 2 can push the setup guide.

- Page 1 — what it is: PCVC logo. "Control your PC's audio from your
  phone." One line about adjusting each application's volume remotely.
- Page 2 — the server: "Your PC needs the free PcVolumeControl server."
  Button "Show me how to set it up" pushes ServerSetupGuideView. Subtext:
  "You can also do this later from the connection screen."
- Page 3 — connecting: on the same Wi-Fi the PC appears automatically
  (mention the green wifi badge on discovered rows); manual IP/port as
  fallback. CTA "Get started" dismisses.

Both Skip and Get Started set `hasSeenIntroTour = true`. The tour never
auto-shows again.

### ServerSetupGuideView (new, `views/ServerSetupGuideView.swift`)

Plain view with no presentation assumptions; works pushed (from the tour)
or inside a sheet (from MainView footer and Settings). Numbered step cards
(number badge, title, short body):

1. Download — "On your Windows PC, download the latest release." `Link`
   opens the GitHub releases URL in Safari.
2. Install and run — run the installer; allow it through Windows Firewall
   when prompted (private networks).
3. Find the address — the server window shows the PC's IP and port
   (default 3000).
4. Connect — back in this app: same Wi-Fi usually means the PC appears
   automatically; otherwise enter the IP and port manually.

Short troubleshooting footer: phone and PC must be on the same network;
check firewall; VPNs can block discovery.

The releases URL is defined once as a constant
(`https://github.com/PcVolumeControl/PcVolumeControlWindows/releases/latest`).

### MainView integration

- Pinned footer below the `List`, inside the existing `VStack`, so it never
  scrolls away: "Don't have the PC server yet? Set it up" presenting
  ServerSetupGuideView in a sheet.
- `.fullScreenCover` presenting IntroTourView when `hasSeenIntroTour` is
  false.

### SettingsView integration

New "Help" section:

- "PC Server Setup Guide" — NavigationLink to ServerSetupGuideView.
- "Replay Intro Tour" — presents IntroTourView as a fullScreenCover
  directly (does not reset the flag).

### UserDefaults

Add `hasSeenIntroTour` to `UserDefaultsKeys` (SettingsView.swift), same
pattern as `hasSeenChatBalanceInfo`.

## Screenshots / CI

`--screenshotMode` (fastlane snapshot) must suppress the auto-shown tour:
the first-launch gate treats screenshot mode as already seen. No periphery
config changes expected; all new views are referenced.

## Error handling

None significant. The only external action is opening a URL in Safari via
`Link`, which the system handles.

## Testing

- Unit test for the first-launch gate logic (flag honored; screenshot mode
  suppresses the tour). Extract the gate decision into a small testable
  helper if needed.
- SwiftUI previews for IntroTourView and ServerSetupGuideView.
- Manual verification: simulator with cleared UserDefaults shows the tour
  once; footer and Settings entries open the guide; download link opens
  Safari.

## Out of scope

- Coach marks on the connect or slider screens.
- A `--mockIntroTour` screenshot flag for App Store shots of the tour.
- QR code or AirDrop-style sharing of the download URL to the PC.
