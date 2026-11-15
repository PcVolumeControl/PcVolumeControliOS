import Foundation

enum WireProtocol {
    /// The only protocol version this app speaks, sent in every message and required in
    /// every full state.
    static let version = 8
}

/// One line received from the server. Every line carries `protocolVersion` and exactly
/// one of `defaultDevice` (a full state) or `icon` (an icon reply).
enum ServerLine {
    case state(FullState)
    case icon(IconReply)

    /// Returns nil for a line to ignore: one that is not a JSON object, has neither or both
    /// of the keys, or is an icon reply without an id. Throws `ProtocolVersionMismatch` for
    /// a full state of another protocol version (checked before the rest is decoded, so the
    /// shape of other versions does not matter) and `MalformedStateError` for a full state
    /// that cannot be decoded.
    static func classify(_ line: Data) throws -> ServerLine? {
        do {
            return try decoder.decode(Envelope.self, from: line).line
        } catch let error as ProtocolVersionMismatch {
            throw error
        } catch let error as MalformedStateError {
            throw error
        } catch {
            return nil
        }
    }

    private static let decoder = JSONDecoder()

    // Decodes the document once and picks the line type by which key is present.
    private struct Envelope: Decodable {
        let line: ServerLine?

        private enum CodingKeys: String, CodingKey {
            case protocolVersion, defaultDevice, icon
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch (container.contains(.defaultDevice), container.contains(.icon)) {
            case (true, false):
                let version: Int
                do {
                    version = try container.decode(Int.self, forKey: .protocolVersion)
                } catch {
                    throw MalformedStateError(underlying: error)
                }
                guard version == WireProtocol.version else {
                    throw ProtocolVersionMismatch(serverVersion: version)
                }
                do {
                    line = .state(try FullState(from: decoder))
                } catch {
                    throw MalformedStateError(underlying: error)
                }
            case (false, true):
                line = .icon(try container.decode(IconReply.self, forKey: .icon))
            default:
                line = nil
            }
        }
    }
}

struct MalformedStateError: LocalizedError {
    let underlying: Error

    var errorDescription: String? {
        "The server sent a full state that could not be read: \(underlying.localizedDescription)"
    }
}

/// The server speaks another protocol version; the connection cannot be used.
struct ProtocolVersionMismatch: LocalizedError {
    let serverVersion: Int

    /// True when the server needs updating, false when this app does.
    var serverIsOlder: Bool {
        serverVersion < WireProtocol.version
    }

    var errorDescription: String? {
        if serverIsOlder {
            return String(localized: "This PC server is too old (protocol version \(serverVersion)). Install the latest PcVolumeControlServer on your PC to use this version of the app.")
        }
        return String(localized: "This PC server is newer than this app (protocol version \(serverVersion)). Update PcVolumeControl on this device to connect to it.")
    }
}

/// The server's answer for one requested icon id.
struct IconReply: Decodable {
    let id: String
    /// The PNG bytes, or nil when the server has no image for the id or sent an unusable payload.
    let png: Data?

    private enum CodingKeys: String, CodingKey {
        case id, data, error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        // Any non-null `error` means "no image". A bad payload must still answer the id,
        // so it maps to "no image" instead of failing the whole line.
        let hasError = container.contains(.error) && (try? container.decodeNil(forKey: .error)) != true
        let base64 = try? container.decodeIfPresent(String.self, forKey: .data)
        let decoded = hasError ? nil : base64.flatMap { Data(base64Encoded: $0) }
        png = decoded?.isEmpty == false ? decoded : nil
    }
}
