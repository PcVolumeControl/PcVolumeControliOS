//
//  ErrorOverlay.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 6/3/25.
//  Copyright © 2025 PcVolumeControl. All rights reserved.
//

import SwiftUI

// A dismissable error overlay with OK button and X close button
struct DismissableErrorOverlay: View {
    var message: String
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Semi-transparent blurred background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .background(Material.ultraThinMaterial)
                .onTapGesture {
                    onDismiss()
                }
            
            // Alert box in the center
            VStack(spacing: 15) {
                // Alert header with title and X button
                HStack {
                    Text("Connection Error")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                // Error message
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                
                // OK button
                Button {
                    onDismiss()
                } label: {
                    Text("OK")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 100, height: 44)
                        .background(Color.sliderPink)
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color.almostBlack)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.sliderPink.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 30)
            .frame(maxWidth: 400)
        }
        .zIndex(999)
    }
}

#Preview {
    DismissableErrorOverlay(message: "Connection to server lost. Please check your network connection and try again.") {
    }
}
