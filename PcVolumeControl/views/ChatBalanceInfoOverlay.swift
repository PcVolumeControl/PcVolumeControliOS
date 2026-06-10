//
//  ChatBalanceInfoOverlay.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 6/4/25.
//  Copyright © 2025 PcVolumeControl. All rights reserved.
//

import SwiftUI

struct ChatBalanceInfoOverlay: View {
    var onDismiss: () -> Void
    
    var body: some View {
        VStack {
            // Overlay content positioned at the top
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .foregroundColor(.pcvcBlue)
                        .font(.system(size: 20))
                    
                    Text("CHAT BALANCE ACTIVATED")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                Text("Move the highlighted slider to automatically balance all other application volumes. Use the menu on any session to change which one is the chat balance control.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    Spacer()
                    Button("OK!") {
                        onDismiss()
                    }
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.pcvcBlue.opacity(0.2))
                    )
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.pcvcBlue.opacity(0.5), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.top, 60) // Position near top but below status bar
            
            Spacer() // Push content to top and allow taps below
        }
        .background(
            // Semi-transparent background that allows seeing content below
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
        )
    }
}

#Preview {
    ZStack {
        Color.almostBlack.ignoresSafeArea()
        
        // Mock slider content
        VStack {
            Text("Slider Content Below")
                .foregroundColor(.white)
                .font(.title)
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 60)
                .cornerRadius(10)
                .padding(.horizontal)
        }
        
        ChatBalanceInfoOverlay {
        }
    }
    .preferredColorScheme(.dark)
}
