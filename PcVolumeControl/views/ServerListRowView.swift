//
//  ServerListRowView.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 6/6/25.
//

import SwiftUI

struct ServerListRowView: View {
    let item: MainViewModel.ServerListItem
    @Binding var manualAddress: String
    @Binding var manualPort: UInt16
    var focusedField: FocusState<MainView.FocusedField?>.Binding
    let onConnect: (DiscoveredServer?) -> Void
    
    @State private var portText: String = ""
    
    var body: some View {
        if item.isManual {
            HStack {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Server IP or Hostname")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("192.168.1.100", text: $manualAddress)
                            .textFieldStyle(CustomTextFieldStyle())
                            .focused(focusedField, equals: .address)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Server Port")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("3000", text: $portText)
                            .textFieldStyle(CustomTextFieldStyle())
                            .keyboardType(.numberPad)
                            .focused(focusedField, equals: .port)
                            .onChange(of: portText) { _, newValue in
                                if newValue.isEmpty {
                                    manualPort = 0
                                } else if let port = UInt16(newValue), port >= 1 && port <= 65535 {
                                    manualPort = port
                                }
                            }

                        if !isPortValid {
                            Text("Please enter a valid TCP port (1-65535)")
                                .font(.caption2)
                                .foregroundColor(.red)
                                .padding(.top, 2)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                Button {
                    onConnect(item.server)
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.sliderPink)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Connect")
            }
            .padding(.vertical, 8)
            .onAppear {
                if manualPort == 0 {
                    portText = ""
                } else {
                    portText = String(manualPort)
                }
            }
            .onChange(of: manualPort) { _, newValue in
                if newValue == 0 {
                    portText = ""
                } else {
                    portText = String(newValue)
                }
            }
        } else if let server = item.server {
            Button {
                onConnect(item.server)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(server.address)
                                .foregroundColor(.white)
                                .font(.headline)

                            if item.isDiscovered {
                                Image(systemName: "wifi")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                        }

                        Text("Port: \(String(server.port))")
                            .foregroundColor(.gray)
                            .font(.subheadline)

                        HStack {
                            if let computerName = server.computerName {
                                Text("(\(computerName))")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }

                            if item.isDiscovered {
                                Text("Auto-discovered")
                                    .foregroundColor(.green)
                                    .font(.caption2)
                            } else if item.isRecent {
                                Text("Recent connection")
                                    .foregroundColor(.gray)
                                    .font(.caption2)
                            }

                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()

                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.sliderPink)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Connect to \(server.computerName ?? server.address)")
            .padding(.vertical, 8)
        }
    }
    
    // Port validation computed property
    private var isPortValid: Bool {
        if portText.isEmpty {
            return true
        }
        
        guard let port = UInt16(portText) else {
            return false
        }
        
        return port >= 1 && port <= 65535
    }
}

#Preview {
    @Previewable @FocusState var focusedField: MainView.FocusedField?
    
    VStack(spacing: 10) {
        // Discovered server row
        ServerListRowView(
            item: .discovered(DiscoveredServer(address: "192.168.1.100", port: 3000, computerName: "DESKTOP-PC")),
            manualAddress: .constant(""),
            manualPort: .constant(0),
            focusedField: $focusedField
        ) { _ in }
        
        // Recent server row
        ServerListRowView(
            item: .recent(DiscoveredServer(address: "10.0.0.5", port: 8080, computerName: nil)),
            manualAddress: .constant(""),
            manualPort: .constant(0),
            focusedField: $focusedField
        ) { _ in }
        
        // Manual entry row
        ServerListRowView(
            item: .manual,
            manualAddress: .constant("192.168.1.50"),
            manualPort: .constant(0),
            focusedField: $focusedField
        ) { _ in }
    }
    .padding()
    .background(Color.almostBlack)
}
