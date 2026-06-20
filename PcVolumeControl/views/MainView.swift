//
//  MainView.swift
//  PCVolumeControl (iOS)
//
//  Created by Bill Booth on 12/29/23.
//

import Combine
import Network
import SwiftUI

struct MainView: View {
    @StateObject private var viewModel: MainViewModel
    @StateObject private var mdnsService = MDNSDiscoveryService()
    @State private var path = NavigationPath()
    enum FocusedField {
        case address, port
    }
    @FocusState private var focusedField: FocusedField?
    @AppStorage(UserDefaultsKeys.hasSeenIntroTour) private var hasSeenIntroTour = false
    @State private var showIntroTour = false
    @State private var showSetupGuide = false
    @State private var showSettings = false
    @AppStorage(UserDefaultsKeys.autoReconnectOnLaunch) private var autoReconnectOnLaunch = false
    @State private var hasAttemptedAutoConnect = false

    init() {
        let local = ServersLocalDataSource()
        let remote = TCPConnectionDataSource()
        let repo = ServersRepository(local: local, remote: remote)
        let connectUseCase = ConnectToServerUseCase(repo: repo)
        
        let placeholderTransport = VolumeTransportDataSource(connection: Connection(nw: NWConnection(host: "127.0.0.1", port: 80, using: .tcp)))
        let placeholderRepo = VolumeControlRepository(transport: placeholderTransport)
        
        _viewModel = StateObject(
            wrappedValue: MainViewModel(
                connect: connectUseCase,
                defUpdate: SendDefaultDeviceUpdateUseCase(repo: placeholderRepo),
                masterUpdate: SendMasterChannelUpdateUseCase(repo: placeholderRepo),
                sessionUpdate: SendSessionUpdateUseCase(repo: placeholderRepo),
                serversRepo: repo
            )
        )
    }
    
    var body: some View {
            NavigationStack(path: $path) {
            ZStack {
                MotionMeshBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // App logo header
                    Image("PCVCLogo")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 78, height: 78)
                        .foregroundStyle(.white)
                        .accessibilityLabel("PcVolumeControl")
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    List {
                        ForEach(viewModel.unifiedServerList) { item in
                            ServerListRowView(
                                item: item,
                                manualAddress: $viewModel.address,
                                manualPort: $viewModel.port,
                                focusedField: $focusedField,
                                onConnect: { server in
                                    if let server = server {
                                        viewModel.selectServer(server)
                                    } else {
                                        // Manual connection
                                        connectToServer()
                                    }
                                }
                            )
                            .listRowBackground(Color.clear)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let item = viewModel.unifiedServerList[index]
                                // Allow deletion for all servers except manual entry row
                                if !item.isManual {
                                    viewModel.deleteServerFromList(item)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    // Pin the top: no rubber-band overscroll, so rows can never
                    // ride up over the logo header above them.
                    .scrollBounceBehavior(.basedOnSize)

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
                        .accessibilityElement(children: .combine)
                    }
                    .accessibilityHint("Opens the Windows server setup guide")

                    // Quiet, secondary entry point to app settings. Placed at the
                    // bottom of the screen so it stays unobtrusive on the connection
                    // screen rather than competing with the logo header up top.
                    Button {
                        showSettings = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "gearshape")
                            Text("Settings")
                        }
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.bottom, 12)
                        .accessibilityElement(children: .combine)
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Opens app settings")
                }
                .readableContentWidth()
            }
            .onTapGesture {
                // Dismiss keyboard when tapping outside text fields
                focusedField = nil
            }
            .overlay {
                if viewModel.isLoading {
                    ConnectingView()
                }
            }
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
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $showIntroTour) {
                IntroTourView {
                    hasSeenIntroTour = true
                    showIntroTour = false
                }
            }
            .alert(alertTitle, isPresented: Binding(get:{ viewModel.error != nil },
                                                 set:{ _ in viewModel.error = nil })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.error ?? "")
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "sliders" {
                    SliderView(path: $path)
                        .environmentObject(viewModel)
                }
            }
            .onChange(of: viewModel.fullState) { oldValue, newValue in
                // Only navigate on the transition into a connection. Navigating on
                // every non-nil update lets a state update racing a disconnect
                // re-push the slider view, making disconnect appear unresponsive.
                if oldValue == nil && newValue != nil && path.isEmpty {
                    // Save successful connection to recent servers
                    viewModel.saveSuccessfulConnection()
                    path.append("sliders")
                }
            }
            .onChange(of: viewModel.error) { oldValue, newValue in
                // If there's an error, make sure we're back on the main view
                if newValue != nil && !path.isEmpty {
                    path = NavigationPath()
                }
            }
            .onChange(of: path) { oldPath, newPath in
                // If user navigated back to main view, ensure we disconnect
                if !oldPath.isEmpty && newPath.isEmpty && viewModel.fullState != nil {
                    viewModel.disconnect()
                }
            }
            .onAppear {
                if IntroTourGate.shouldShowTour(hasSeenTour: hasSeenIntroTour) {
                    // Defer one run-loop turn so the NavigationStack finishes its
                    // first layout before the fullScreenCover presents; presenting
                    // synchronously in onAppear can be dropped on first launch.
                    Task { @MainActor in showIntroTour = true }
                }
                #if DEBUG
                if configureForScreenshotsIfNeeded() { return }
                #endif
                viewModel.loadRecentServers()
                mdnsService.startDiscovery()

                // Cold-launch auto-connect. The one-shot flag persists for the app
                // process, so returning to this screen (e.g. after a manual
                // disconnect) does NOT re-trigger a connection.
                if !hasAttemptedAutoConnect,
                   AutoReconnectGate.shouldAutoConnect(
                       isEnabled: autoReconnectOnLaunch,
                       hasRecentServer: !viewModel.recentServers.isEmpty) {
                    hasAttemptedAutoConnect = true
                    viewModel.autoConnectToLastServer()
                }
            }
            .onDisappear {
                mdnsService.stopDiscovery()
            }
            .onChange(of: mdnsService.discoveredServers) { oldServers, newServers in
                viewModel.handleDiscoveredServers(newServers)
            }
            .onChange(of: viewModel.address) { oldValue, newValue in
                viewModel.handleManualAddressChange(newValue)
            }
            .onChange(of: viewModel.port) { oldValue, newValue in
                viewModel.handleManualPortChange(newValue)
            }
            } // NavigationStack
    }
    
    // MARK: - Computed Properties
    
    private var alertTitle: String {
        if let error = viewModel.error, error.contains("timeout") {
            return "Connection Timeout"
        }
        return "Connection Error"
    }
    
    // MARK: - Private Methods

    private func connectToServer() {
        // Port resolution (blank -> default) is handled by the view model.
        viewModel.connectToServer(address: viewModel.address, port: viewModel.port)
    }

    #if DEBUG
    // Configures deterministic state for fastlane snapshot.
    //
    // Returns true when launched with --screenshotMode, in which case live mDNS
    // discovery and recent-server loading are skipped so the screens are stable.
    // The connection screen then shows a fixed manual server address. Passing
    // --mockConnected additionally injects a live session so the slider and
    // settings screens can be captured without a real PC server.
    private func configureForScreenshotsIfNeeded() -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--screenshotMode") else { return false }

        // Start from a clean, deterministic list (no live discovery or recents).
        viewModel.recentServers = []
        viewModel.discoveredServers = []

        // Auto-discovery showcase: a server broadcasting over mDNS appears in the
        // list and auto-fills the connection fields, exactly like live discovery.
        if arguments.contains("--mockDiscovered") {
            let server = DiscoveredServer(address: "192.168.0.42", port: 3000, computerName: "MYPC")
            viewModel.handleDiscoveredServers([server])
            return true
        }

        // Deterministic manual-entry values for the plain connection screen.
        viewModel.address = "192.168.0.17"
        viewModel.port = 3000

        guard arguments.contains("--mockConnected") else { return true }

        // Delay lets the NavigationStack finish its initial layout before the
        // fullState change triggers navigation to SliderView.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            // Volumes are on a 0...100 scale (see SessionCell/TopCell slider range).
            let sessions = [
                FullState.Session(id: "1", muted: false, name: "Spotify", volume: 65),
                FullState.Session(id: "2", muted: false, name: "Discord", volume: 80),
                FullState.Session(id: "3", muted: true,  name: "Chrome", volume: 40),
                FullState.Session(id: "4", muted: false, name: "System Sounds", volume: 30),
            ]
            let device = FullState.theDefaultDevice(
                deviceId: "mock-device",
                masterMuted: false,
                masterVolume: 75,
                name: "Speakers (HDMI)",
                sessions: sessions
            )
            // Multiple output devices so the master-device selector has a
            // meaningful list; "mock-device" is the selected default.
            viewModel.fullState = FullState(
                protocolVersion: 7,
                deviceIds: [
                    "mock-device": "Speakers (HDMI)",
                    "headphones": "Headphones (Bluetooth)",
                    "realtek": "Realtek Digital Output",
                    "monitor": "Monitor Audio (DisplayPort)",
                ],
                defaultDevice: device
            )
        }
        return true
    }
    #endif
}

#Preview {
    MainView()
        .preferredColorScheme(.dark)
}

#Preview("With Recent Servers") {
    // Create a preview version with mock recent servers
    let preview = MainView()
    // Note: In a real implementation, you'd mock the ServersLocalDataSource 
    // to return test data, but this gives an idea of the UI
    return preview
        .preferredColorScheme(.dark)
}
