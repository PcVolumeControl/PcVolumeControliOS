//
//  AutoReconnectGate.swift
//  PcVolumeControl
//
//  Decides whether the app should auto-connect to the last-used server on launch.
//

import Foundation

enum AutoReconnectGate {
    // Fastlane snapshot launches with --screenshotMode and needs deterministic
    // screens, so auto-connect never fires there.
    static func shouldAutoConnect(
        isEnabled: Bool,
        hasRecentServer: Bool,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        if arguments.contains("--screenshotMode") { return false }
        return isEnabled && hasRecentServer
    }
}
