# Motion Mesh Gradient Background — Design

Date: 2026-06-07
Status: Approved, ready for implementation plan

## Summary

Replace the app's flat `almostBlack` background with an animated `MeshGradient` backdrop that subtly reacts to device tilt. A cool deep-blue/violet palette sits behind every screen (server list, slider screen, settings, connecting overlay). Mesh control points shift gently with device orientation; in the absence of motion data the same view continues with slow ambient drift.

## Goals

- Add visual depth and "alive" feel without competing with the UI.
- Reuse a single background for all primary screens — one source of truth for the look.
- Keep CPU/GPU and battery cost low; never block or jitter the UI thread.
- Degrade gracefully when motion data is unavailable (simulator, restricted devices).

## Non-goals

- No audio reactivity, connection-state reactivity, or master-volume coupling. Tilt only.
- No light-mode design pass. App remains dark-mode-only for this change.
- No widget treatment. The widget keeps its current appearance; a static snapshot can be considered as a follow-up.
- No new motion permissions / Info.plist additions (none required for live `CMDeviceMotion`).

## User-facing behavior

- On every full-screen view in the app, the background is a smooth multi-color mesh gradient in deep blues, violets, indigo, and teal — dark enough that existing white text, `sliderPink`, and `masterAccent` gold remain legible and on-brand.
- As the user tilts the device, the mesh interior gently shifts (perceptible but not distracting). Edges of the mesh stay anchored, so the screen frame reads as stable.
- When the device is held still, the mesh slowly drifts on its own (ambient motion). It is never a frozen image.
- If motion data is unavailable (simulator, hardware fault), the ambient drift continues — the only visible difference is no tilt response.

## Architecture

Two small units behind a single SwiftUI view.

### `MotionProvider` (`ObservableObject`, `@MainActor`)

Wraps `CMMotionManager`. Owns lifecycle and smoothing.

- Public: `@Published var tilt: Tilt` where `Tilt` is `(roll: Double, pitch: Double)` normalized to `[-1, 1]`.
- Internal:
  - `CMMotionManager` with `deviceMotionUpdateInterval = 1/30` (30 Hz).
  - One-pole low-pass filter: `smoothed = smoothed + α * (raw - smoothed)`, α ≈ 0.12 per sample. Justifies "subtle" response feel; filters out wrist jitter.
  - Clamp raw attitude to ±~25° before normalizing; anything outside that maps to ±1.
  - Start/stop methods called from view lifecycle.
- Hardware seam: introduce a small protocol (`MotionSource`) so tests can feed synthetic samples without touching `CMMotionManager`. Production implementation wraps `CMMotionManager`; test implementation is a struct or class controlled by the test.
- Fallback: if `isDeviceMotionAvailable == false`, or no sample arrives within 1 s of `start()`, `tilt` stays `.zero`. No branching at the view layer.

### `MotionMeshBackground` (`View`)

Renders the mesh.

- Wrapped in `TimelineView(.animation)` so the ambient phase advances each frame on visible windows only.
- Reads `MotionProvider` from the environment.
- Computes 20 mesh control points each frame (cheap; just `SIMD2<Float>` math).
- Renders one `MeshGradient` filling the bounds, `.ignoresSafeArea()`.

### Mesh specifics

- Grid: 4 columns × 5 rows = 20 points.
- Outer ring (12 points): pinned to view bounds — keeps the frame sealed regardless of tilt or phase.
- Inner 6 points (one 2×3 interior block): mobile.
- Per-point offset formula (in normalized mesh `[0,1]` space):
  - `point = basePoint + tilt * amplitude + ambient(phase, i)`
  - `amplitude ≈ 0.06` — small fraction of a cell.
  - `ambient(phase, i)`: per-point Lissajous with distinct frequencies/phases per index, magnitude ≈ 0.015. Generates slow continuous wandering with no two points in sync.
  - Net effect: inner points stay clear of neighbors and the boundary; no mesh self-intersection.
- Palette: 20 colors mapped to the 20 control points. Cool deep palette:
  - Outer ring: near-black indigo (`#0A0E1F` family).
  - Inner band: deep blue (~`#1B2A6B`), violet (~`#3A1E78`), teal (~`#0E3B4E`), midnight (~`#101428`).
  - Exact hex values to be locked in implementation, validated visually against existing UI chrome (slider pink, master gold, white text) for AA contrast.

## Integration

- Introduce background once, at the app root (`PcVolumeControlApp.swift`), as a `ZStack` underlay beneath the `WindowGroup`'s root content.
- `MotionProvider` lives as a single `@StateObject` at the app root, exposed via `.environmentObject(_:)`.
- Per-screen changes:
  - Remove or change to `.clear` any `Color.almostBlack.ignoresSafeArea()` background calls in `MainView`, `SliderView`, `ConnectingView`, `SettingsView`, etc.
  - `List` rows that currently use `.listRowBackground(Color.almostBlack)` either:
    - become `Color.clear` plus their own translucent card style for legibility, or
    - move to `.ultraThinMaterial`-backed rows over the mesh.
  - The exact list-row approach is chosen during implementation by visual check; either way the mesh shows through framing.
- Uncomment / replace the existing placeholder references to `MotionMeshGradientView()` in `MainView.swift` (currently commented out on two lines) — they become unnecessary because the background is installed at the root.

## Lifecycle and power

- `MotionProvider.start()` called when the root background view appears.
- `MotionProvider.stop()` called on `.onDisappear` and on `ScenePhase` transition to `.background` / `.inactive`.
- `start()` again on transition back to `.active`.
- `TimelineView(.animation)` only ticks while the view is on-screen; no manual frame loop.
- Frame rate: rely on SwiftUI's default schedule (matches display). No manual `CADisplayLink`.

## Permissions

None. Live `CMDeviceMotion` does not require a runtime permission or an `NSMotionUsageDescription`. (That key is only needed for `CMMotionActivityManager` historical activity classification, which we do not use.)

## Testing

### Unit tests (`MotionProviderTests`)

- Inject a `MotionSource` test double that feeds synthetic `(roll, pitch)` samples.
- Assert:
  - Low-pass filter damps a step input over the expected number of samples.
  - Clamp behavior: inputs beyond ±25° saturate to ±1 in normalized space.
  - With `isDeviceMotionAvailable == false`, `tilt` remains `.zero`.
  - With motion source going silent after start, `tilt` settles to `.zero` (no stale lingering value).
- All synchronous; no real `CMMotionManager` touched.

### Snapshot / visual tests

- Snapshot `MotionMeshBackground` at:
  - `tilt = (0, 0)`, `phase = 0`
  - `tilt = (1, -1)`, `phase = 0`
- Locks the visual contract so palette/grid regressions are caught.

### Manual verification checklist

- Simulator: ambient drift visible, no tilt response (expected — no motion).
- Physical iPhone: tilt response visible and damped; no jitter.
- Background → foreground: mesh resumes smoothly; no permission prompts.
- Low Power Mode: still animates (SwiftUI may reduce frame rate; that's acceptable).
- Slider screen: dragging a slider on top of the mesh is still legible; no perceived hitch.

## File layout

```
PcVolumeControl/views/background/
  MotionMeshBackground.swift      // view, mesh point math, TimelineView
  MotionProvider.swift            // CMMotionManager wrapper, smoothing, lifecycle
  MotionMeshPalette.swift         // 20 colors + base point grid + amplitudes
PcVolumeControlTests/
  MotionProviderTests.swift
```

`UIStyling.swift` keeps the existing named brand colors unchanged. The 20-color mesh palette lives in `MotionMeshPalette.swift` so future palette tuning is a single-file change.

## Risks and mitigations

- **List rows look muddy on top of the mesh.** Mitigation: choose between transparent rows + per-cell card style and `.ultraThinMaterial` rows during implementation; either preserves legibility.
- **Mesh palette competes with `sliderPink` accents.** Mitigation: palette is intentionally cool; no warm hues. Validate visually with the slider screen open before locking palette hex values.
- **Battery cost from continuous motion + animation.** Mitigation: 30 Hz motion updates, stop on background, no manual display link, single `MeshGradient` view (GPU-cheap).
- **`MotionProvider` start/stop races on rapid scene-phase flips.** Mitigation: idempotent start/stop with a small `isRunning` flag; CMMotionManager is robust to re-`startDeviceMotionUpdates` calls but we guard anyway.

## Out of scope (potential follow-ups)

- Widget visual unification (would need a static mesh snapshot, since widgets can't run CoreMotion or per-frame animation).
- Light-mode palette.
- Accessibility "Reduce Motion" handling — if the user has Reduce Motion enabled, the ambient drift and tilt response should both be disabled and the mesh rendered statically. (Mentioned here because it's a likely follow-up; not in this scope unless added explicitly.)
