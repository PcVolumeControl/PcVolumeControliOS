//
//  PcVolumeControlWidget.swift
//  PcVolumeControlWidget
//
//  Created by Bill Booth on 10/19/25.
//  Copyright © 2025 PcVolumeControl. All rights reserved.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Timeline Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), state: placeholderState())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let state = SharedStateManager.readState() ?? placeholderState()
        let entry = SimpleEntry(date: Date(), state: state)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let state = SharedStateManager.readState() ?? placeholderState()

        // Create entry for current state
        let entry = SimpleEntry(date: currentDate, state: state)

        // Refresh every 30 seconds to update staleness indicators
        let nextUpdate = Calendar.current.date(byAdding: .second, value: 30, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }

    private func placeholderState() -> SharedConnectionState {
        SharedConnectionState(
            isConnected: false,
            serverName: "Desktop PC",
            masterVolume: 75,
            chatVolume: 60,
            chatSessionName: "Discord"
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let state: SharedConnectionState
}

// MARK: - Widget Entry View

struct PcVolumeControlWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallWidgetView(state: entry.state)
                .containerBackground(Color.black, for: .widget)
        case .accessoryCircular:
            CircularWidgetView(state: entry.state)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        case .accessoryRectangular:
            RectangularWidgetView(state: entry.state)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        case .accessoryInline:
            InlineWidgetView(state: entry.state)
        default:
            SmallWidgetView(state: entry.state)
                .containerBackground(Color.black, for: .widget)
        }
    }
}

// MARK: - Small Home Screen Widget

struct SmallWidgetView: View {
    let state: SharedConnectionState

    var body: some View {
        VStack(spacing: 6) {
                // Header with connection status
                HStack {
                    Circle()
                        .fill(connectionColor)
                        .frame(width: 8, height: 8)

                    Text(state.displayServerName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()
                }

                // Connection status text
                Text(connectionStatusText)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // Volume information
                if state.isConnected && !state.isStale {
                    VStack(spacing: 4) {
                        // Master volume with circular progress indicator
                        ZStack {
                            // Background circle
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                                .frame(width: 70, height: 70)

                            // Progress circle
                            Circle()
                                .trim(from: 0, to: state.masterVolume / 100)
                                .stroke(
                                    Color.yellow,
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                )
                                .frame(width: 70, height: 70)
                                .rotationEffect(.degrees(-90))

                            // Volume percentage text
                            VStack(spacing: 1) {
                                Text("\(Int(state.masterVolume))%")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("Master")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }

                        // Chat balance volume if available
                        if let chatVolume = state.chatVolume {
                            HStack(spacing: 6) {
                                Text(state.chatSessionName ?? "Chat")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)

                                Spacer()

                                // Mini progress bar for chat
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 35, height: 4)

                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.blue)
                                        .frame(width: 35 * (chatVolume / 100), height: 4)
                                }

                                Text("\(Int(chatVolume))%")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color.blue.opacity(0.8))
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                } else {
                    // Stale or disconnected state
                    VStack(spacing: 4) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.title3)
                            .foregroundColor(.orange)

                        Text(state.isConnected ? "Connection stale" : "Disconnected")
                            .font(.caption)
                            .foregroundColor(.gray)

                        if !state.isStale {
                            Text("Master: \(Int(state.masterVolume))%")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }

                Spacer()

                // Tap to open indicator
                Text("Tap to open")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .widgetURL(URL(string: "pcvolumecontrol://connect"))
    }

    private var connectionColor: Color {
        if state.isConnected && !state.isStale {
            return .green
        } else if state.isConnected {
            return .orange
        } else {
            return .gray
        }
    }

    private var connectionStatusText: String {
        if state.isConnected && !state.isStale {
            return "Connected"
        } else if state.isConnected {
            return "Last seen \(state.staleDurationString)"
        } else {
            return "Not connected"
        }
    }
}

// MARK: - Lock Screen Circular Widget

struct CircularWidgetView: View {
    let state: SharedConnectionState

    var body: some View {
        ZStack {
            // Background ring showing connection status
            Circle()
                .stroke(connectionColor, lineWidth: 4)

            VStack(spacing: 2) {
                if state.isConnected && !state.isStale {
                    // Show volume when connected
                    Text("\(Int(state.masterVolume))")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("%")
                        .font(.caption2)
                } else {
                    // Show warning when disconnected
                    Image(systemName: "exclamationmark")
                        .font(.title2)
                        .foregroundColor(connectionColor)
                }
            }
        }
        .widgetURL(URL(string: "pcvolumecontrol://connect"))
    }

    private var connectionColor: Color {
        if state.isConnected && !state.isStale {
            return .green
        } else {
            return .orange
        }
    }
}

// MARK: - Lock Screen Rectangular Widget

struct RectangularWidgetView: View {
    let state: SharedConnectionState

    var body: some View {
        HStack(spacing: 8) {
            // Connection indicator
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)

            if state.isConnected && !state.isStale {
                // Connected: Show volumes
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(state.displayServerName)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text("M: \(Int(state.masterVolume))%")
                            .font(.caption2)

                        if let chatVolume = state.chatVolume {
                            Text("C: \(Int(chatVolume))%")
                                .font(.caption2)
                        }
                    }
                    .foregroundColor(.secondary)
                }
            } else {
                // Disconnected: Show status
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.displayServerName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text("Tap to connect")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .widgetURL(URL(string: "pcvolumecontrol://connect"))
    }

    private var connectionColor: Color {
        if state.isConnected && !state.isStale {
            return .green
        } else {
            return .orange
        }
    }
}

// MARK: - Lock Screen Inline Widget

struct InlineWidgetView: View {
    let state: SharedConnectionState

    var body: some View {
        if state.isConnected && !state.isStale {
            Text("🔊 \(state.displayServerName): \(Int(state.masterVolume))%")
        } else {
            Text("⚠️ \(state.displayServerName): Tap to connect")
        }
    }
}

// MARK: - Widget Configuration

struct PcVolumeControlWidget: Widget {
    let kind: String = "PcVolumeControlWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            PcVolumeControlWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("PC Volume")
        .description("View and control your PC's volume.")
        .supportedFamilies([
            .systemSmall,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    PcVolumeControlWidget()
} timeline: {
    SimpleEntry(date: .now, state: SharedConnectionState(
        isConnected: true,
        serverName: "Desktop PC",
        masterVolume: 75,
        chatVolume: 60,
        chatSessionName: "Discord"
    ))
    SimpleEntry(date: .now, state: SharedConnectionState(
        isConnected: false,
        serverName: "Desktop PC",
        masterVolume: 75
    ))
}

#Preview(as: .accessoryCircular) {
    PcVolumeControlWidget()
} timeline: {
    SimpleEntry(date: .now, state: SharedConnectionState(
        isConnected: true,
        serverName: "Desktop PC",
        masterVolume: 75
    ))
}

#Preview(as: .accessoryRectangular) {
    PcVolumeControlWidget()
} timeline: {
    SimpleEntry(date: .now, state: SharedConnectionState(
        isConnected: true,
        serverName: "Desktop PC",
        masterVolume: 75,
        chatVolume: 60
    ))
}
