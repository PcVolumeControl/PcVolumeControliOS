import Foundation

/// Lightweight logging shim used in place of bare `print`.
///
/// In Debug builds this writes to the console exactly like `print`. In Release
/// builds the body compiles to nothing and the message is never evaluated, so
/// diagnostic output (and its string-interpolation cost) never ships to users'
/// device consoles. Shared by the app and the widget extension.
func appLog(_ message: @autoclosure () -> Any) {
    #if DEBUG
    print(message())
    #endif
}
