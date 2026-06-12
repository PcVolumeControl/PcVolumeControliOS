//
//  IntroTourGate.swift
//  PcVolumeControl
//
//  Decides whether the first-launch intro tour should auto-present.
//

import Foundation

enum IntroTourGate {
    // Fastlane snapshot launches with --screenshotMode and needs
    // deterministic screens, so the tour never auto-shows there.
    static func shouldShowTour(
        hasSeenTour: Bool,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        if arguments.contains("--screenshotMode") { return false }
        return !hasSeenTour
    }
}
