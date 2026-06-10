//
//  SessionCell.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 6/4/25.
//  Copyright © 2025 PcVolumeControl. All rights reserved.
//

import SwiftUI


struct HorizontalTickSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let steps: Int
    var accessibilityLabel: String = "Volume"
    let onEditingChanged: (Bool) -> Void
    let onValueChange: (Double) -> Void
    let onCommit: () -> Void

    var body: some View {
        ZStack {
            // 1) Tick marks under the track
            GeometryReader { _ in
                HStack(spacing: 0) {
                    ForEach(0...steps, id: \.self) { index in
                        if index == 0 {
                            Rectangle()
                                .frame(width: 1, height: 8)
                                .foregroundColor(.secondary.opacity(0.5))
                        } else {
                            Spacer()
                            Rectangle()
                                .frame(width: 1, height: 8)
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 8)
            .offset(y: 8)

            // 2) The actual Slider
            Slider(value: $value, in: range) { editing in
                onEditingChanged(editing)
                if !editing {
                    onCommit()
                }
            }
            .onChange(of: value) { oldValue, newValue in
                onValueChange(newValue)
            }
            .accentColor(.sliderPink)
            .frame(height: 44)
            .padding(.horizontal, 8)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue("\(Int(value)) percent")
        }
        .frame(height: 44)
    }
}

struct RecessedCapsuleToggleStyle: ToggleStyle {
    @ScaledMetric(relativeTo: .body) private var knobSize: CGFloat = 38
    @ScaledMetric(relativeTo: .body) private var trackWidth: CGFloat = 90

    func makeBody(configuration: Configuration) -> some View {
        let horizontalPadding: CGFloat = 4
        let verticalPadding: CGFloat   = 4
        let trackHeight                = knobSize + verticalPadding * 2.5
        let maxOffset                  = (trackWidth - knobSize) / 2 - horizontalPadding

        return Button {
            let haptic = UIImpactFeedbackGenerator(style: .medium)
            haptic.impactOccurred()
            withAnimation(.easeOut(duration: 0.2)) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack {
                // 1) Recessed track
                Capsule()
                    .fill(configuration.isOn ? Color.white.opacity(0.12) : Color.red.opacity(0.7))
                    .frame(width: trackWidth, height: trackHeight)
                    .overlay( // inner‐highlight
                        Capsule()
                            .stroke(Color.white.opacity(0.3), lineWidth: 4.5)
                            .blur(radius: 2)
                            .offset(x: 1, y: -3)
                            .mask(
                                Capsule().fill(
                                    LinearGradient(
                                        gradient: .init(colors: [.black, .clear]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            )
                    )
                    .overlay( // inner‐shadow
                        Capsule()
                            .stroke(Color.black.opacity(0.9), lineWidth: 4.5)
                            .blur(radius: 1.5)
                            .offset(x: 1, y: 3)
                            .mask(
                                Capsule().fill(
                                    LinearGradient(
                                        gradient: .init(colors: [.clear, .black]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            )
                    )

                // 2) Knob inset by our padding
                Circle()
                    .fill(Color(Color.almostBlack))
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .offset(x: configuration.isOn ? maxOffset : -maxOffset)
                    // ← **here** we overlay the Toggle’s label onto the knob
                    .overlay(
                        configuration.label
                            .font(.caption2)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    )
            }
        }
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "on" : "off")
        .buttonStyle(PlainButtonStyle())
    }
}




struct SessionCell: View {
    @Binding var session: FullState.Session
    var isChat: Bool = false
    var chatMode: Bool = false
    var isMasterMuted: Bool = false
    var isChatBalanceActive: Bool = false
    var onBeginEditing: () -> Void
    var onEndEditing: () -> Void
    var onChatSelect: (String) -> Void
    var onVolumeDuringDrag: (String, Double) -> Void
    var onCommit: (FullState.Session) -> Void
    var onChatBalanceCommit: (() -> Void)?
    var backgroundColor: Color = .almostBlack
    var toggleMuted: Color = .sliderPink
    var toggleUnmuted: Color = .white

    @EnvironmentObject private var aliasManager: AliasManager
    @Environment(\.editMode) private var editMode

    // Local state for slider to prevent visual jumps
    @State private var localVolume: Double = 0
    @State private var ignoreServerUpdates = false
    // Animate slider changes only while the cell is settled on-screen; off during appear so scroll-in snaps.
    @State private var animationsEnabled = false
    // Show a dialog to edit the alias for this session
    @State private var isEditingAlias = false
    @State private var newAlias = ""

    private var isInEditMode: Bool {
        editMode?.wrappedValue == .active
    }

    // The volume the slider should display: zero whenever the session or the
    // master is muted, otherwise the session's real volume. Centralized here so
    // every place that sets localVolume stays mute-aware, including onAppear
    // when a cell is recreated after scrolling back on-screen.
    static func displayVolume(volume: Double, muted: Bool, masterMuted: Bool) -> Double {
        (muted || masterMuted) ? 0 : volume
    }

    private var displayVolume: Double {
        SessionCell.displayVolume(
            volume: session.volume,
            muted: session.muted,
            masterMuted: isMasterMuted
        )
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Drag handle indicator - only visible in edit mode
            if isInEditMode {
                HStack {
                    Spacer()
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(.white.opacity(0.3))
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                }
                .padding(.top, 8)
            }

            HStack {
                // Chat balance indicator
                if isChat {
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .foregroundColor(.pcvcBlue)
                        .font(.system(size: 16))
                }

                // Use alias if available, otherwise use original name
                Text(aliasManager.displayNameForSession(sessionId: session.id, originalName: session.name))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                // Chat balance mode indicator
                if chatMode && !isChat {
                    Text("AUTO")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.pcvcBlue.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.pcvcBlue.opacity(0.2))
                        )
                }

                // Context menu button
                Menu {
                    Button {
                        onChatSelect(session.id)
                    } label: {
                        Label(
                            isChat ? "Remove from Chat Balance" : "Set as Chat Balance",
                            systemImage: isChat ? "xmark.circle" : "arrow.up.arrow.down.circle"
                        )
                    }

                    Button {
                        showAliasEditingPrompt()
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.gray)
                        .font(.system(size: 20))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.top, isInEditMode ? 0 : 8)
            
            // Volume controls - all in one horizontal row
            HStack(spacing: 12) {
                // Volume slider
                HorizontalTickSlider(
                    value: $localVolume,
                    range: 0...100,
                    steps: 10,
                    accessibilityLabel: "Volume for \(aliasManager.displayNameForSession(sessionId: session.id, originalName: session.name))",
                    onEditingChanged: { editing in
                        if editing {
                            ignoreServerUpdates = true
                            onBeginEditing()
                        } else {
                            let haptic = UISelectionFeedbackGenerator()
                            haptic.selectionChanged()
                            session.volume = localVolume
                            onVolumeDuringDrag(session.id, localVolume)
                            if isChat && isChatBalanceActive {
                                onChatBalanceCommit?()
                            } else {
                                onCommit(session)
                            }

                            // Allow server updates immediately after committing
                            ignoreServerUpdates = false
                            onEndEditing()
                        }
                    },
                    onValueChange: { newValue in
                        // live updates during drag
                        if isChat && chatMode {
                            onVolumeDuringDrag(session.id, newValue)
                        }
                    },
                    onCommit: {
                        // final commit already handled above
                    }
                )
                .disabled(session.muted || isMasterMuted || (isChatBalanceActive && !isChat))
                .padding(.leading, 8)
                // Animate localVolume only when the cell is settled on-screen and not dragging.
                .animation((animationsEnabled && !ignoreServerUpdates) ? .easeOut(duration: 0.3) : nil, value: localVolume)

                Toggle(isOn: Binding(
                    get:  { !session.muted },
                    set:  { newValue in
                      session.muted = !newValue
                      onCommit(session)
                    }
                  )
                ) {
                  if session.muted {
                    Image(systemName: "speaker.slash.fill")
                      .foregroundColor(toggleMuted)
                      .offset(x: -22)
                      .imageScale(.large)

                  } else {
                    Text("\(Int(localVolume))")
                      .foregroundColor(toggleUnmuted)
                      .offset(x: 22)
                      .font(.system(.body, design: .rounded))
                  }
                }
                .toggleStyle(RecessedCapsuleToggleStyle())
                .disabled(isMasterMuted)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor.opacity(0.55))
                .overlay(
                    // Blue outline for chat balance session
                    isChat ?
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.pcvcBlue, lineWidth: 2)
                    : nil
                )
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
        )
        .onAppear {
            // Snap to current value on appear; re-enable animation next runloop so scroll-in catch-ups don't slide.
            animationsEnabled = false
            localVolume = displayVolume
            DispatchQueue.main.async { animationsEnabled = true }
        }
        .onDisappear { animationsEnabled = false }
        .onChange(of: session.volume) { _, _ in
            // Only update our local value if we're not ignoring server updates
            if !ignoreServerUpdates {
                localVolume = displayVolume
            }
        }
        .onChange(of: session.muted) { _, _ in
            localVolume = displayVolume
        }
        .onChange(of: isMasterMuted) { _, _ in
            localVolume = displayVolume
        }
        // Add alias editing dialog
        .alert("Set Custom Name", isPresented: $isEditingAlias) {
            TextField("Custom name", text: $newAlias)
                .autocorrectionDisabled()
                .autocapitalization(.words)
            
            Button("Save") {
                // Save the new alias if it's not empty
                aliasManager.setSessionAlias(originalId: session.id, alias: newAlias)
            }
            
            Button("Clear", role: .destructive) {
                // Remove any existing alias
                aliasManager.setSessionAlias(originalId: session.id, alias: "")
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a custom name for \"\(session.name)\"")
        }
    }
    
    private func showAliasEditingPrompt() {
        // Initialize with current alias if exists
        newAlias = aliasManager.sessionAliases[session.id] ?? ""
        isEditingAlias = true
    }
}

#Preview {
    @Previewable @State var mockSession = FullState.Session(
        id: "radio.exe",
        muted: false,
        name: "Radio",
        volume: 75.0
    )
    
    SessionCell(
        session: $mockSession,
        isChat: false,
        chatMode: false,
        isMasterMuted: false,
        isChatBalanceActive: false,
        onBeginEditing: { },
        onEndEditing: { },
        onChatSelect: { _ in },
        onVolumeDuringDrag: { _, _ in },
        onCommit: { _ in },
        onChatBalanceCommit: nil
    )
    .environmentObject(AliasManager())
    .preferredColorScheme(.dark)
    .padding()
}

#Preview("Chat Balance Mode") {
    @Previewable @State var mockSession = FullState.Session(
        id: "discord.exe",
        muted: false,
        name: "Discord",
        volume: 50.0
    )
    
    SessionCell(
        session: $mockSession,
        isChat: true,
        chatMode: true,
        isMasterMuted: false,
        isChatBalanceActive: true,
        onBeginEditing: { },
        onEndEditing: { },
        onChatSelect: { _ in },
        onVolumeDuringDrag: { _, _ in },
        onCommit: { _ in },
        onChatBalanceCommit: { }
    )
    .environmentObject(AliasManager())
    .preferredColorScheme(.dark)
    .padding()
}
