import SwiftUI

struct SliderView: View {
    @EnvironmentObject private var mainVM: MainViewModel
    @StateObject private var vm = SliderViewModel()
    @Binding var path: NavigationPath

    @State private var showSettings = false
    @State private var showOverlay  = false

    // Connection-status banner; lives outside the disabled content so its buttons stay tappable.
    @ViewBuilder
    private var connectionBanner: some View {
        switch mainVM.connectionStatus {
        case .reconnecting:
            HStack(spacing: 8) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.8)
                Text("Connection lost \u{2013} reconnecting\u{2026}")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.orange.opacity(0.85))

        case .lost:
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)
                Text("Server disconnected")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
                Button("Reconnect") { mainVM.reconnect() }
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Button {
                    mainVM.disconnect()
                    path = NavigationPath()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.white.opacity(0.85))
                }
                .accessibilityLabel("Leave")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.85))

        case .connected:
            EmptyView()
        }
    }

    var body: some View {
        ZStack {
            MotionMeshBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                connectionBanner

                // Frozen and dimmed unless the connection is live.
                VStack(spacing: 0) {
                TopCell(
                    internalDefault: .constant(vm.defaultDevice),
                    internalDevices: .constant(vm.devices),
                    onBeginEditing: { vm.beginEditing(nil) },
                    onEndEditing:   { vm.endEditing(nil) },
                    onMasterCommit: mainVM.updateMaster,
                    onDefaultDeviceChange: mainVM.updateDefaultDevice,
                    onShowSettings: { showSettings = true },
                    onDisconnect: {
                        // Disconnect authoritatively before popping; a bare path change can race a server re-push.
                        mainVM.disconnect()
                        path = NavigationPath()
                    }
                )

                List {
                    ForEach($vm.sessions) { $session in
                        SessionCell(
                            session: $session,
                            isChat:  vm.chatBalanceSessionId == session.id,
                            chatMode: vm.chatBalanceMode,
                            isMasterMuted: vm.isMasterMuted,
                            isChatBalanceActive: vm.chatBalanceMode,
                            onBeginEditing: { vm.beginEditing(session.id) },
                            onEndEditing:   { vm.endEditing(session.id) },
                            onChatSelect:   vm.toggleChatBalance,
                            onVolumeDuringDrag: vm.applyChatBalance,
                            onCommit: { sess in
                                Task { try? await mainVM.updateSession(sess) }
                            },
                            onChatBalanceCommit: vm.chatBalanceSessionId == session.id ? {
                                vm.commitChatBalanceChanges { sess in
                                    Task { try? await mainVM.updateSession(sess) }
                                }
                            } : nil
                        )
                    }
                    .onMove(perform: vm.reorder)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                }
                .disabled(!mainVM.isConnectionLive)
                .opacity(mainVM.isConnectionLive ? 1 : 0.5)
            }
            .toolbar(.hidden, for: .navigationBar)
            .readableContentWidth()

            if showOverlay {
                DismissableErrorOverlay(message: "Connection to server lost") {
                    showOverlay = false
                }
            }
            
            if vm.showChatBalanceInfo {
                ChatBalanceInfoOverlay {
                    vm.dismissChatBalanceInfo()
                }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .navigationBarBackButtonHidden()
        .onReceive(mainVM.$fullState) { newState in
            vm.fullState = newState
        }
    }
}

#Preview {
    @Previewable @State var mockPath = NavigationPath()
    
    NavigationStack(path: $mockPath) {
        ZStack {
            Color.almostBlack.ignoresSafeArea()
            Text("SliderView Preview")
                .foregroundColor(.white)
                .font(.title)
        }
        .environmentObject(AliasManager())
        .preferredColorScheme(.dark)
    }
}

#Preview("Static Layout") {
    ZStack {
        Color.almostBlack.ignoresSafeArea()
        
        VStack {
            Text("Slider Layout Preview")
                .font(.title)
                .foregroundColor(.white)
                .padding()
            
            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}
