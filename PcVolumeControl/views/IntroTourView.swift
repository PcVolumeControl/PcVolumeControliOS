//
//  IntroTourView.swift
//  PcVolumeControl
//
//  Three-page first-launch welcome tour. Page 2 pushes the server
//  setup guide. Skip and Get Started both call onFinish; the caller
//  is responsible for persisting hasSeenIntroTour and dismissing.
//

import SwiftUI

struct IntroTourView: View {
    var onFinish: () -> Void

    @State private var page = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.almostBlack.ignoresSafeArea()

                TabView(selection: $page) {
                    whatItIsPage.tag(0)
                    serverPage.tag(1)
                    connectPage.tag(2)
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") {
                        onFinish()
                    }
                    .foregroundColor(.gray)
                    .accessibilityHint("Closes the intro tour")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var whatItIsPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image("PCVCLogo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .foregroundStyle(.white)
            Text("Control your PC's audio from your phone")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("Adjust the volume of every application on your Windows PC remotely. Turn the game down without leaving voice chat behind.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var serverPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "desktopcomputer")
                .font(.system(size: 64))
                .foregroundColor(.sliderPink)
                .accessibilityHidden(true)
            Text("Your PC needs the free server")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("This app talks to the PcVolumeControl server, a small program that runs on your Windows PC.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            NavigationLink {
                ServerSetupGuideView()
            } label: {
                Text("Show me how to set it up")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.sliderPink))
            }
            Text("You can also do this later from the connection screen.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var connectPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "wifi")
                .font(.system(size: 64))
                .foregroundColor(.green)
                .accessibilityHidden(true)
            Text("Connecting is automatic")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("On the same Wi-Fi network, your PC appears in the server list with a green Wi-Fi badge. Tap it to connect, or enter an IP address and port manually.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button {
                onFinish()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.sliderPink))
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    IntroTourView {
    }
    .preferredColorScheme(.dark)
}
