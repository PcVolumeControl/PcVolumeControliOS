//
//  TopCell.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 6/4/25.
//  Copyright © 2025 PcVolumeControl. All rights reserved.
//

import SwiftUI

struct TopCell: View {
    @Binding var internalDefault: FullState.theDefaultDevice?
    @Binding var internalDevices: [String: String]

    var onBeginEditing: () -> Void
    var onEndEditing:   () -> Void
    var onMasterCommit: (String, Bool, Double) -> Void
    var onDefaultDeviceChange: (String) -> Void
    var onShowSettings: () -> Void
    var onDisconnect: () -> Void

    @EnvironmentObject private var aliasManager: AliasManager

    // Local state for master volume slider to prevent visual jumps
    @State private var localMasterVolume: Double = 0
    @State private var ignoreServerUpdates = false
    @State private var showDevicePicker = false

    var body: some View {
        VStack(spacing: 12) {
            // Drag handle indicator (matching SessionCell)
            HStack {
                Spacer()
//                Image(systemName: "line.3.horizontal")
//                    .foregroundColor(.masterAccent.opacity(0.3))
//                    .font(.system(size: 12, weight: .medium))
//                Spacer()
            }
            .padding(.top, 8)

            // Device name header with long-press gesture
            if let device = internalDefault {
                HStack {
                    Image("PCVCLogo")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundColor(.masterAccent)

                    Button {
                        showDevicePicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(aliasManager.displayNameForDevice(deviceId: internalDevices[device.deviceId] ?? "", originalName: internalDevices[device.deviceId] ?? "Master Device"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Image(systemName: "chevron.down")
                                .foregroundColor(.masterAccent.opacity(0.6))
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Select master device")
                    .accessibilityHint("Opens a picker to choose the active output device")

                    Spacer()

                    // Overflow menu (edit name, settings, disconnect)
                    Menu {
                        Button {
                            showAliasEditingPrompt()
                        } label: {
                            Label("Edit Name", systemImage: "pencil")
                        }
                        Button {
                            onShowSettings()
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        Button(role: .destructive) {
                            onDisconnect()
                        } label: {
                            Label("Disconnect", systemImage: "power")
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18))
                            .foregroundColor(.masterAccent.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("More options")
                }
                .padding(.horizontal, 12)

                // Master Volume Controls - Slider and Mute inline
                HStack(spacing: 12) {
                    // Volume slider
                    HorizontalTickSlider(
                        value: $localMasterVolume,
                        range: 0...100,
                        steps: 10,
                        accessibilityLabel: "Master volume",
                        onEditingChanged: { editing in
                            if editing {
                                ignoreServerUpdates = true
                                onBeginEditing()
                            } else {
                                let haptic = UISelectionFeedbackGenerator()
                                haptic.selectionChanged()
                                onMasterCommit(device.deviceId, device.masterMuted, localMasterVolume)

                                // Allow server updates immediately after committing
                                ignoreServerUpdates = false
                                onEndEditing()
                            }
                        },
                        onValueChange: { _ in },
                        onCommit: {}
                    )
                    .accentColor(.masterAccent)
                    .padding(.leading, 8)

                    // Mute toggle with volume percentage
                    Toggle(isOn: Binding(
                        get: { !device.masterMuted },
                        set: { newValue in
                            onMasterCommit(device.deviceId, !newValue, device.masterVolume)
                        }
                    )) {
                        if device.masterMuted {
                            Image(systemName: "speaker.slash.fill")
                                .foregroundColor(.red)
                                .offset(x: -22)
                                .imageScale(.large)
                        } else {
                            Text("\(Int(localMasterVolume))")
                                .foregroundColor(.masterAccent)
                                .offset(x: 22)
                                .font(.system(.body, design: .rounded))
                        }
                    }
                    .toggleStyle(RecessedCapsuleToggleStyle())
                    .accessibilityLabel("Master mute")
                    .accessibilityValue(device.masterMuted ? "muted" : "unmuted")
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.masterBackground.opacity(0.55))
        .onAppear {
            if let device = internalDefault {
                localMasterVolume = device.masterVolume
            }
        }
        .onChange(of: internalDefault?.masterVolume) { _, newValue in
            if !ignoreServerUpdates, let volume = newValue {
                localMasterVolume = volume
            }
        }
        .onChange(of: internalDefault?.masterMuted) { _, masterMuted in
            guard let masterMuted, let device = internalDefault else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                localMasterVolume = masterMuted ? 0 : device.masterVolume
            }
        }
        // Device picker sheet
        .sheet(isPresented: $showDevicePicker) {
            DevicePickerSheet(
                devices: internalDevices,
                selectedDeviceId: internalDefault?.deviceId,
                onSelect: { key in
                    onDefaultDeviceChange(key)
                }
            )
            .environmentObject(aliasManager)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        // Add alias editing dialog for master device
        .alert("Set Master Device Name", isPresented: $isEditingAlias) {
            TextField("Custom name", text: $newAlias)
                .autocorrectionDisabled()
                .autocapitalization(.words)

            Button("Save") {
                if let device = internalDefault {
                    aliasManager.setDeviceAlias(originalId: device.name, alias: newAlias)
                }
            }

            Button("Clear", role: .destructive) {
                if let device = internalDefault {
                    aliasManager.setDeviceAlias(originalId: device.name, alias: "")
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            if let device = internalDefault {
                Text("Enter a custom name for \"\(internalDevices[device.name] ?? device.name)\"")
            }
        }
    }

    // Dialog state for editing master device alias
    @State private var isEditingAlias = false
    @State private var newAlias = ""

    private func showAliasEditingPrompt() {
        // Initialize with current alias if exists
        if let device = internalDefault {
            newAlias = aliasManager.deviceAliases[device.name] ?? ""
        }
        isEditingAlias = true
    }
}

private struct DevicePickerSheet: View {
    let devices: [String: String]
    let selectedDeviceId: String?
    let onSelect: (String) -> Void

    @EnvironmentObject private var aliasManager: AliasManager
    @Environment(\.dismiss) private var dismiss

    private func displayName(for key: String) -> String {
        let original = devices[key] ?? ""
        return aliasManager.displayNameForDevice(deviceId: original, originalName: original)
    }

    private var sortedKeys: [String] {
        devices.keys.sorted {
            displayName(for: $0).localizedCaseInsensitiveCompare(displayName(for: $1)) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    ForEach(sortedKeys, id: \.self) { key in
                        let isSelected = key == selectedDeviceId
                        Button {
                            onSelect(key)
                            dismiss()
                        } label: {
                            HStack {
                                Text(displayName(for: key))
                                    .foregroundColor(.primary)
                                    .fontWeight(isSelected ? .semibold : .regular)
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.masterAccent)
                                        .fontWeight(.semibold)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .listRowBackground(isSelected ? Color.masterAccent.opacity(0.15) : nil)
                    }
                }
                .onAppear {
                    if let selectedDeviceId {
                        proxy.scrollTo(selectedDeviceId, anchor: .center)
                    }
                }
            }
            .navigationTitle("Select Master Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var mockDevice: FullState.theDefaultDevice? = FullState.theDefaultDevice(
        deviceId: "speaker-12345",
        masterMuted: false,
        masterVolume: 80.0,
        name: "External Speakers",
        sessions: []
    )

    @Previewable @State var mockDevices = [
        "speaker-12345": "External Speakers",
        "headphones-67890": "Headphones (Bluetooth)",
        "monitor-11111": "Monitor Audio (HDMI)"
    ]

    TopCell(
        internalDefault: $mockDevice,
        internalDevices: $mockDevices,
        onBeginEditing: { },
        onEndEditing: { },
        onMasterCommit: { _, _, _ in },
        onDefaultDeviceChange: { _ in },
        onShowSettings: { },
        onDisconnect: { }
    )
    .environmentObject(AliasManager())
    .preferredColorScheme(.dark)
    .padding()
}

#Preview("Muted State") {
    @Previewable @State var mockDevice: FullState.theDefaultDevice? = FullState.theDefaultDevice(
        deviceId: "speaker-12345",
        masterMuted: true,
        masterVolume: 80.0,
        name: "Speakers (Realtek High Definition Audio)",
        sessions: []
    )

    @Previewable @State var mockDevices = [
        "speaker-12345": "Speakers (Realtek High Definition Audio)",
        "headphones-67890": "Headphones (Bluetooth)",
        "monitor-11111": "Monitor Audio (HDMI)"
    ]

    TopCell(
        internalDefault: $mockDevice,
        internalDevices: $mockDevices,
        onBeginEditing: { },
        onEndEditing: { },
        onMasterCommit: { _, _, _ in },
        onDefaultDeviceChange: { _ in },
        onShowSettings: { },
        onDisconnect: { }
    )
    .environmentObject(AliasManager())
    .preferredColorScheme(.dark)
    .padding()
}
