//
//  UIStyling.swift
//  PCVolumeControl (iOS)
//
//  Created by Bill Booth on 1/13/24.
//

import SwiftUI


extension Color {
    static let almostBlack = Color(red: 30 / 255, green: 30 / 255, blue: 30 / 255)
    static let sliderPink = Color(red: 255 / 255, green: 56 / 255, blue: 122 / 255)
    static let pcvcBlue = Color(red: 70 / 255, green: 33 / 255, blue: 255 / 255)
    static let masterBackground = Color(red: 40 / 255, green: 40 / 255, blue: 50 / 255)
    static let masterAccent = Color(red: 251 / 255, green: 192 / 255, blue: 45 / 255) // Gold accent for master controls
}

extension View {
    // Caps foreground content to a comfortable, centered column and keeps it
    // centered in the available space. A no-op on iPhone (the screen is narrower
    // than the cap); on iPad it stops controls from stretching edge-to-edge.
    func readableContentWidth(_ maxWidth: CGFloat = 600) -> some View {
        self
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
}

// Custom styling for text fields
struct CustomTextFieldStyle: TextFieldStyle {
    // periphery:ignore - _body is the TextFieldStyle protocol requirement, invoked by SwiftUI
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(15)
            .background(Color.almostBlack)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .foregroundColor(.white)
    }
}
