import Foundation

enum IconId {
    /// Icon ids are 1 to 64 characters of `[a-z0-9]`, which also makes them safe file names.
    static func isValid(_ id: String) -> Bool {
        let bytes = id.utf8
        return (1...64).contains(bytes.count)
            && bytes.allSatisfy { (0x30...0x39).contains($0) || (0x61...0x7A).contains($0) }
    }
}
