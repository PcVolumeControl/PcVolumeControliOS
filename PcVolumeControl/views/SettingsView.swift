//
//  SettingsView.swift
//  PcVolumeControl
//
//
//

import SwiftUI

struct UserDefaultsKeys {
    static let preserveSessionOrder = "preserveSessionOrder"
    static let hasSeenChatBalanceInfo = "hasSeenChatBalanceInfo"
    static let hasSeenIntroTour = "hasSeenIntroTour"
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage(UserDefaultsKeys.preserveSessionOrder) private var preserveSessionOrder = true
    @State private var showIntroTour = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Session Preferences")) {
                    Toggle("Preserve Session Order", isOn: $preserveSessionOrder)
                        .tint(.sliderPink)
                    
                    Text("When enabled, your manually arranged session order will be preserved when you restart the app.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Section(header: Text("Custom Names")) {
                    Text("You can create custom names for both devices and sessions by tapping their names or using the pencil icons.")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    NavigationLink(destination: AliasListView()) {
                        Text("Manage Custom Names")
                    }
                }
                
                Section(header: Text("Help")) {
                    NavigationLink(destination: ServerSetupGuideView()) {
                        Text("PC Server Setup Guide")
                    }

                    Button("Replay Intro Tour") {
                        showIntroTour = true
                    }
                    .foregroundColor(.white)
                }

                Section(header: Text("About")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("PC Volume Control")
                            .font(.headline)
                        
                        Text("Control your PC application volume from your iOS device.")
                            .font(.caption)
                            .foregroundColor(.gray)
                        HStack {
                            Text("Version 2.0.0")
                                .font(.caption)
                            Text("Protocol Version: 7")
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .background(Color.almostBlack.edgesIgnoringSafeArea(.all))
            .fullScreenCover(isPresented: $showIntroTour) {
                IntroTourView {
                    showIntroTour = false
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}


struct AliasListView: View {
    @EnvironmentObject private var aliasManager: AliasManager
    @State private var deviceAliasToEdit: (key: String, value: String)? = nil
    @State private var sessionAliasToEdit: (key: String, value: String)? = nil
    @State private var newAlias = ""
    
    var body: some View {
        List {
            Section(header: Text("Master Devices")) {
                if aliasManager.deviceAliases.isEmpty {
                    Text("No custom device names set")
                        .foregroundColor(.gray)
                        .italic()
                } else {
                    ForEach(Array(aliasManager.deviceAliases), id: \.key) { key, value in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(value)
                                    .fontWeight(.medium)
                                Text(key)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            // Edit button
                            Button {
                                deviceAliasToEdit = (key, value)
                                newAlias = value
                            } label: {
                                Image(systemName: "pencil")
                                    .imageScale(.medium)
                                    .foregroundColor(.sliderPink)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Tapping the row also opens the edit dialog
                            deviceAliasToEdit = (key, value)
                            newAlias = value
                        }
                    }
                }
            }
            
            Section(header: Text("Sessions")) {
                if aliasManager.sessionAliases.isEmpty {
                    Text("No custom session names set")
                        .foregroundColor(.gray)
                        .italic()
                } else {
                    ForEach(Array(aliasManager.sessionAliases), id: \.key) { key, value in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(value)
                                    .fontWeight(.medium)
                                Text(key)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            // Edit button
                            Button {
                                sessionAliasToEdit = (key, value)
                                newAlias = value
                            } label: {
                                Image(systemName: "pencil")
                                    .imageScale(.medium)
                                    .foregroundColor(.sliderPink)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Tapping the row also opens the edit dialog
                            sessionAliasToEdit = (key, value)
                            newAlias = value
                        }
                    }
                }
            }
        }
        .navigationTitle("Custom Names")
        // Edit name alert
        .alert("Edit Custom Name", isPresented: .init(
            get: { deviceAliasToEdit != nil || sessionAliasToEdit != nil },
            set: { if !$0 { 
                // Just clear the editing state, don't make any changes to the actual aliases
                deviceAliasToEdit = nil
                sessionAliasToEdit = nil 
            }}
        )) {
            TextField("Enter new name", text: $newAlias)
                .autocorrectionDisabled()
                .autocapitalization(.words)
            
            Button("Save") {
                if let device = deviceAliasToEdit {
                    aliasManager.setDeviceAlias(originalId: device.key, alias: newAlias)
                } else if let session = sessionAliasToEdit {
                    aliasManager.setSessionAlias(originalId: session.key, alias: newAlias)
                }
                deviceAliasToEdit = nil
                sessionAliasToEdit = nil
            }
            
            Button("Delete", role: .destructive) {
                if let device = deviceAliasToEdit {
                    aliasManager.setDeviceAlias(originalId: device.key, alias: "")
                } else if let session = sessionAliasToEdit {
                    aliasManager.setSessionAlias(originalId: session.key, alias: "")
                }
                deviceAliasToEdit = nil
                sessionAliasToEdit = nil
            }
            
            Button("Cancel", role: .cancel) {
                // Simply clear the edit states without making changes
                deviceAliasToEdit = nil
                sessionAliasToEdit = nil
                // Don't modify aliases when canceling
            }
        }
    }
}

#Preview {
    SettingsView()
}
