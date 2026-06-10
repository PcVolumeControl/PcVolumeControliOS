//
//  ConnectingView.swift
//  PCVolumeControl (iOS)
//
//  Created by Bill Booth on 1/1/24.
//

import SwiftUI

struct ConnectingView: View {

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.sliderPink))
                .scaleEffect(3)
        }
    }
}

#Preview {
    ConnectingView()
        .preferredColorScheme(.dark)
}
