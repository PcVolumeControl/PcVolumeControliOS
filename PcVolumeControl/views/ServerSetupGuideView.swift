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
    static let organizationURL = URL(string: "https://github.com/PcVolumeControl")!
    static var supportedProtocolVersion: Int { VolumeControlRepository.protocolVersion }
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
                    .accessibilityLabel("Download PcVolumeControlWindows releases on GitHub")
                    ShareLink(item: ServerDownload.releasesURL) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share download link")
                        }
                        .font(.footnote)
                        .foregroundColor(.sliderPink)
                    }
                    .accessibilityLabel("Share the download link to open on your PC")
                }

                SetupStepRow(number: 2, title: "Install and run it") {
                    Text("Run the installer, then start the server. If Windows Firewall asks, click Allow so the server can accept connections on private networks.")
                }

                SetupStepRow(number: 3, title: "Find the address") {
                    Text("The server window shows your PC's IP address and port. The default port is 3000.")
                }

                SetupStepRow(number: 4, title: "Connect from this app") {
                    Text("With your device on the same Wi-Fi network as the PC, your computer usually appears in the server list automatically. Otherwise, type the IP address and port manually.")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Trouble connecting?")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("Make sure this device and PC are on the same network, the server is allowed through Windows Firewall, and no VPN is active on either device. VPNs often block local discovery.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 6) {
                    Text("We're open source. Report bugs, ask questions, or submit pull requests on GitHub!")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Link(destination: ServerDownload.organizationURL) {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                            Text("Find us on GitHub")
                        }
                        .font(.footnote)
                        .foregroundColor(.sliderPink)
                    }
                    .accessibilityLabel("Find PcVolumeControl on GitHub")
                }
                .padding(.top, 4)

                Text("App \(Bundle.main.appVersion) · Server protocol v\(ServerDownload.supportedProtocolVersion)")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
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
                .accessibilityHidden(true)

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
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        ServerSetupGuideView()
    }
    .preferredColorScheme(.dark)
}
