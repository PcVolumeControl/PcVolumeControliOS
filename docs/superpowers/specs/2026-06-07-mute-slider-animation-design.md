# Mute Slider Animation Design

## Goal

When a session or the master is muted, its volume slider animates smoothly to 0. When unmuted, the slider animates back to the stored volume. The animation uses `.easeOut(duration: 0.3)` — full speed at start, decelerates into the final position.

## Scope

- Session muted/unmuted by the user or server: that session's slider animates
- Master muted: all session sliders animate to 0, master slider animates to 0
- Master unmuted: all session sliders animate back to their volume, master slider animates back

## Changes

### SessionCell.swift

Two `onChange` observers added to `SessionCell.body`:

**Session own mute:**
```swift
.onChange(of: session.muted) { _, muted in
    withAnimation(.easeOut(duration: 0.3)) {
        localVolume = muted ? 0 : session.volume
    }
}
```

**Master mute affecting session:**
```swift
.onChange(of: isMasterMuted) { _, masterMuted in
    withAnimation(.easeOut(duration: 0.3)) {
        localVolume = masterMuted ? 0 : session.volume
    }
}
```

### TopCell.swift

One `onChange` observer added to `TopCell.body`:

```swift
.onChange(of: internalDefault?.masterMuted) { _, masterMuted in
    guard let masterMuted, let device = internalDefault else { return }
    withAnimation(.easeOut(duration: 0.3)) {
        localMasterVolume = masterMuted ? 0 : device.masterVolume
    }
}
```

## Invariants

- `session.volume` and `device.masterVolume` are never modified — only `localVolume` / `localMasterVolume` (the visual state) changes
- `ignoreServerUpdates` is unaffected — the animation only touches the display value, not the committed value
- If both master and session are muted, both handlers fire but both target `0` — no conflict
- Server-initiated mute changes (another client) also trigger the animation via `onChange(of: session.muted)`
