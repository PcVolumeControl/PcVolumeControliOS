import Foundation
import SwiftUI

/// Manages user-defined aliases for devices and sessions
class AliasManager: ObservableObject {
    private let deviceAliasesKey = "deviceAliases"
    private let sessionAliasesKey = "sessionAliases"
    @Published var deviceAliases: [String: String] = [:]
    @Published var sessionAliases: [String: String] = [:]
    private let defaults = UserDefaults.standard
    
    init() {
        loadAliases()
    }
    
    func loadAliases() {
        if let savedDeviceAliases = defaults.dictionary(forKey: deviceAliasesKey) as? [String: String] {
            deviceAliases = savedDeviceAliases
        }
        
        if let savedSessionAliases = defaults.dictionary(forKey: sessionAliasesKey) as? [String: String] {
            sessionAliases = savedSessionAliases
        }
    }
    
    func saveAliases() {
        defaults.set(deviceAliases, forKey: deviceAliasesKey)
        defaults.set(sessionAliases, forKey: sessionAliasesKey)
    }
    
    func setDeviceAlias(originalId: String, alias: String) {
        if alias.isEmpty {
            deviceAliases.removeValue(forKey: originalId)
        } else {
            deviceAliases[originalId] = alias
        }
        saveAliases()
    }
    
    func setSessionAlias(originalId: String, alias: String) {
        if alias.isEmpty {
            sessionAliases.removeValue(forKey: originalId)
        } else {
            sessionAliases[originalId] = alias
        }
        saveAliases()
    }
    
    func displayNameForDevice(deviceId: String, originalName: String) -> String {
        return deviceAliases[deviceId] ?? originalName
    }
    
    func displayNameForSession(sessionId: String, originalName: String) -> String {
        return sessionAliases[sessionId] ?? originalName
    }
}
