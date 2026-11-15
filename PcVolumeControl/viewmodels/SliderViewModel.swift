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
            saveOrderIfChanged()
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
    
    private func updateSessionsRespectingDebounce(with incoming: [FullState.Session]) {
        // If preserving order and we have a saved order, use it
        if preserveSessionOrder && !savedOrder.isEmpty {
            updateWithSavedOrder(incomingSessions: incoming)
        }
        // If we have sessions and user has reordered, preserve current order
        else if !sessions.isEmpty {
            updatePreservingCurrentOrder(incomingSessions: incoming)
        }
        // Otherwise sort alphabetically, but respect editingIds
        else {
            let sortedSessions = incoming.sorted(by: Self.inDisplayOrder)

            // If any sessions are being edited, preserve their values
            if !editingIds.isEmpty {
                sessions = sortedSessions.map { incoming in
                    if editingIds.contains(incoming.id),
                       let existing = sessions.first(where: { $0.id == incoming.id }) {
                        return incoming.keepingUserValues(of: existing)
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
        let saved = savedOrder
        let savedIds = Set(saved)
        for sessionId in saved {
            if let session = incomingDict[sessionId] {
                if editingIds.contains(sessionId), 
                   let existingIdx = sessions.firstIndex(where: { $0.id == sessionId }) {
                    orderedSessions.append(session.keepingUserValues(of: sessions[existingIdx]))
                } else {
                    orderedSessions.append(session)
                }
            }
        }
        
        // Add new sessions not in saved order
        for session in incomingSessions {
            if !savedIds.contains(session.id) {
                remainingSessions.append(session)
            }
        }
        
        remainingSessions.sort(by: Self.inDisplayOrder)
        sessions = orderedSessions + remainingSessions
        
        // Update saved order
        saveOrderIfChanged()
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
                updatedSessions.append(incoming.keepingUserValues(of: session))
            } else {
                updatedSessions.append(incoming)
            }
        }
        
        // Add new sessions at the end
        let existingIds = Set(sessions.map { $0.id })
        let newSessions = incomingSessions.filter { !existingIds.contains($0.id) }
        let sortedNewSessions = newSessions.sorted(by: Self.inDisplayOrder)
        
        sessions = updatedSessions + sortedNewSessions
        
        if preserveSessionOrder {
            saveOrderIfChanged()
        }
    }

    // States can arrive every second (session details), so skip writes that change nothing.
    private func saveOrderIfChanged() {
        let order = sessions.map { $0.id }
        if order != savedOrder {
            savedOrder = order
        }
    }

    // By name; same-named sessions (told apart only by their detail) by id, numbers in ids
    // compared numerically, so their order is stable and never depends on the detail.
    private static func inDisplayOrder(_ lhs: FullState.Session, _ rhs: FullState.Session) -> Bool {
        switch lhs.name.localizedCaseInsensitiveCompare(rhs.name) {
        case .orderedAscending: return true
        case .orderedDescending: return false
        case .orderedSame:
            switch lhs.id.localizedStandardCompare(rhs.id) {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame: return lhs.id < rhs.id
            }
        }
    }
}

private extension FullState.Session {
    /// This incoming session with the volume and mute of `existing`, for a session the user is editing.
    func keepingUserValues(of existing: FullState.Session) -> FullState.Session {
        var merged = self
        merged.muted = existing.muted
        merged.volume = existing.volume
        return merged
    }
}
