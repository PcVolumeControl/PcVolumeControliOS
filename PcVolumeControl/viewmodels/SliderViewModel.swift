//
//  SliderViewModel.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 6/4/25.
//  Copyright © 2025 PcVolumeControl. All rights reserved.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class SliderViewModel: ObservableObject {
    // Inputs
    @Published var fullState: FullState? {
        didSet { apply(fullState) }
    }

    // Outputs the views bind to
    @Published var sessions: [FullState.Session] = []
    @Published private(set) var defaultDevice: FullState.theDefaultDevice?
    @Published private(set) var devices: [String: String] = [:]
    
    // Computed property for master mute state
    var isMasterMuted: Bool {
        defaultDevice?.masterMuted ?? false
    }

    // User prefs
    @AppStorage(UserDefaultsKeys.preserveSessionOrder) private var preserveSessionOrder = false
    private var savedOrder: [String] {
        get { UserDefaults.standard.array(forKey: "savedSessionOrder") as? [String] ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "savedSessionOrder") }
    }
    private var editingIds = Set<String>()      // debounce guard

    // Chat-balance
    @Published var chatBalanceSessionId: String?
    @Published var chatBalanceMode = false
    @Published var showChatBalanceInfo = false

    // MARK: – Public intents called by the view
    func beginEditing(_ id: String?) {
        if let id {
            editingIds.insert(id)
        }
    }
    func endEditing (_ id: String?)  {
        if let id {
            editingIds.remove(id)
        }
    }
    
    func reorder(from source: IndexSet, to destination: Int) {
        sessions.move(fromOffsets: source, toOffset: destination)
        if preserveSessionOrder {
            savedOrder = sessions.map { $0.id }
        }
    }

    func toggleChatBalance(for id: String)   {
        if chatBalanceSessionId == id && chatBalanceMode {
            // Disable chat balance for this session
            chatBalanceMode = false
            chatBalanceSessionId = nil

            // Clear any editing state from non-chat sessions
            for session in sessions where session.id != id {
                editingIds.remove(session.id)
            }
        } else {
            // Enable chat balance for this session
            chatBalanceSessionId = id
            chatBalanceMode = true

            // Check if user has seen the info before
            if !UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasSeenChatBalanceInfo) {
                showChatBalanceInfo = true
            }
        }
    }
    
    func dismissChatBalanceInfo() {
        showChatBalanceInfo = false
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasSeenChatBalanceInfo)
    }
    
    func commitChatBalanceChanges(onCommit: @escaping (FullState.Session) -> Void) {
        guard chatBalanceMode else { return }
        
        // Mark all sessions as editing to prevent server updates from overwriting during commit
        for session in sessions {
            editingIds.insert(session.id)
        }
        
        // Send updates for all sessions that were affected by chat balance
        for session in sessions {
            onCommit(session)
        }
        
        // Clear editing state after debounce period
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            for session in self.sessions {
                self.editingIds.remove(session.id)
            }
        }
    }
    func applyChatBalance(id _: String, vol: Double) {
        guard let chatSessionId = chatBalanceSessionId else { return }

        // Crossfade approach: Chat volume directly controls the inverse of other volumes
        // Chat at 0% = Others at 100%
        // Chat at 50% = Others at 50%
        // Chat at 100% = Others at 0%

        let chatVolume = vol
        let othersVolume = 100.0 - chatVolume

        // Mark all non-chat sessions as editing to prevent server updates during drag
        for session in sessions where session.id != chatSessionId {
            editingIds.insert(session.id)
        }

        // Apply the inverse volume to all other sessions
        for index in sessions.indices {
            let session = sessions[index]

            if session.id == chatSessionId {
                // This is the chat balance session, don't modify it here
                continue
            }

            // Set all other sessions to the inverse of chat volume
            sessions[index].volume = othersVolume
        }
    }

    // MARK: – Private
    private func apply(_ state: FullState?) {
        guard let state else { return }

        updateMasterRespectingDebounce(with: state.defaultDevice)
        updateSessionsRespectingDebounce(with: state.defaultDevice.sessions)
        devices = state.deviceIds
    }
    
    // Parse session name from ID and fallback name using new protocol
    private func parseSessionDisplayName(sessionId: String, fallbackName: String) -> String {
        // Check for new protocol format: |PCVC#<purpose>
        if let pcvcRange = sessionId.range(of: "|PCVC#") {
            let purposeStart = sessionId.index(pcvcRange.upperBound, offsetBy: 0)
            let purpose = String(sessionId[purposeStart...])
            
            // Convert purpose to user-friendly display name
            switch purpose.lowercased() {
            case "discord-voice":
                return "Discord (Voice)"
            case "discord-notifications":
                return "Discord (Notifications)"
            default:
                // For other purposes, capitalize and format nicely
                let formattedPurpose = purpose.replacingOccurrences(of: "-", with: " ")
                    .split(separator: " ")
                    .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                    .joined(separator: " ")
                return "\(fallbackName) (\(formattedPurpose))"
            }
        }
        
        // Use existing backward compatible logic
        return fallbackName
    }

    private func updateSessionsRespectingDebounce(with incoming: [FullState.Session]) {
        // Apply new naming protocol to sessions
        let processedSessions = incoming.map { session in
            let displayName = parseSessionDisplayName(sessionId: session.id, fallbackName: session.name)
            return FullState.Session(
                id: session.id,
                muted: session.muted,
                name: displayName,
                volume: session.volume
            )
        }

        // If preserving order and we have a saved order, use it
        if preserveSessionOrder && !savedOrder.isEmpty {
            updateWithSavedOrder(incomingSessions: processedSessions)
        }
        // If we have sessions and user has reordered, preserve current order
        else if !sessions.isEmpty {
            updatePreservingCurrentOrder(incomingSessions: processedSessions)
        }
        // Otherwise sort alphabetically, but respect editingIds
        else {
            let sortedSessions = processedSessions.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

            // If any sessions are being edited, preserve their values
            if !editingIds.isEmpty {
                sessions = sortedSessions.map { incoming in
                    if editingIds.contains(incoming.id),
                       let existing = sessions.first(where: { $0.id == incoming.id }) {
                        // Keep current values for editing session
                        return FullState.Session(
                            id: existing.id,
                            muted: existing.muted,
                            name: incoming.name,
                            volume: existing.volume
                        )
                    } else {
                        return incoming
                    }
                }
            } else {
                sessions = sortedSessions
            }
        }
    }

    private func updateMasterRespectingDebounce(with device: FullState.theDefaultDevice) {
        // If editing, preserve current values, otherwise use server values
        if editingIds.contains("master"), let current = defaultDevice {
            // Keep current volume/mute values but update name/id
            defaultDevice = FullState.theDefaultDevice(
                deviceId: device.deviceId,
                masterMuted: current.masterMuted,
                masterVolume: current.masterVolume,
                name: device.name,
                sessions: device.sessions
            )
        } else {
            defaultDevice = device
        }
    }
    
    
    private func updateWithSavedOrder(incomingSessions: [FullState.Session]) {
        // Handle duplicate session IDs by keeping only the first occurrence
        var incomingDict = [String: FullState.Session]()
        for session in incomingSessions {
            if incomingDict[session.id] == nil {
                incomingDict[session.id] = session
            }
        }
        var orderedSessions = [FullState.Session]()
        var remainingSessions = [FullState.Session]()
        
        // Add sessions in saved order
        for sessionId in savedOrder {
            if let session = incomingDict[sessionId] {
                if editingIds.contains(sessionId), 
                   let existingIdx = sessions.firstIndex(where: { $0.id == sessionId }) {
                    // Keep current values for editing session
                    let existing = sessions[existingIdx]
                    orderedSessions.append(FullState.Session(
                        id: sessionId,
                        muted: existing.muted,
                        name: session.name,
                        volume: existing.volume
                    ))
                } else {
                    orderedSessions.append(session)
                }
            }
        }
        
        // Add new sessions not in saved order
        for session in incomingSessions {
            if !savedOrder.contains(session.id) {
                remainingSessions.append(session)
            }
        }
        
        remainingSessions.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        sessions = orderedSessions + remainingSessions
        
        // Update saved order
        savedOrder = sessions.map { $0.id }
    }
    
    private func updatePreservingCurrentOrder(incomingSessions: [FullState.Session]) {
        // Handle duplicate session IDs by keeping only the first occurrence
        var incomingDict = [String: FullState.Session]()
        for session in incomingSessions {
            if incomingDict[session.id] == nil {
                incomingDict[session.id] = session
            }
        }
        var updatedSessions = [FullState.Session]()
        
        // Update existing sessions, preserving order
        for session in sessions {
            guard let incoming = incomingDict[session.id] else { continue }
            
            if editingIds.contains(session.id) {
                // Keep current values for editing session
                updatedSessions.append(FullState.Session(
                    id: session.id,
                    muted: session.muted,
                    name: incoming.name,
                    volume: session.volume
                ))
            } else {
                updatedSessions.append(incoming)
            }
        }
        
        // Add new sessions at the end
        let existingIds = Set(sessions.map { $0.id })
        let newSessions = incomingSessions.filter { !existingIds.contains($0.id) }
        let sortedNewSessions = newSessions.sorted { 
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending 
        }
        
        sessions = updatedSessions + sortedNewSessions
        
        if preserveSessionOrder {
            savedOrder = sessions.map { $0.id }
        }
    }
}
