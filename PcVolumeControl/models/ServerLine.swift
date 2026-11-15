import Foundation

/// One line received from the server. Every line carries `protocolVersion` and exactly
/// one of `defaultDevice` (a full state) or `icon` (an icon reply); anything else,
/// including lines that are not valid JSON, is ignored for forward compatibility.
enum ServerLine {
    case state(FullState)
    case icon(IconReply)
    case ignored

    static func classify(_ line: Data) -> ServerLine {
        (try? JSONDecoder().decode(Envelope.self, from: line))?.line ?? .ignored
    }

    // Decodes the document once and picks the line type by which key is present.
    private struct Envelope: Decodable {
        let line: ServerLine

        private enum CodingKeys: String, CodingKey {
            case defaultDevice, icon
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch (container.contains(.defaultDevice), container.contains(.icon)) {
            case (true, false):
                line = .state(try FullState(from: decoder))
            case (false, true):
                line = .icon(try container.decode(IconReply.self, forKey: .icon))
            default:
                line = .ignored
            }
        }
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
        // Any `error` value means "no image". A bad payload must still produce a reply
        // for the id, so it is mapped to "no image" instead of failing the whole line.
        let error = try? container.decodeIfPresent(String.self, forKey: .error)
        let base64 = try? container.decodeIfPresent(String.self, forKey: .data)
        png = error == nil ? base64.flatMap { Data(base64Encoded: $0) } : nil
    }
}
