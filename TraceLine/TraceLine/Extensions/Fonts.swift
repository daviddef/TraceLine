import UIKit

/// The wireframe asks for `-apple-system` (SF Pro), with a monospace face for retro.
/// SF Pro can't be used here: `SKLabelNode(fontNamed:)` resolves fonts by PostScript
/// name, and the system font's name (".SFUI-Bold") is private — passing it silently
/// falls back to Times. Avenir Next is the closest face guaranteed to be installed.
enum Fonts {
    static let bold   = "AvenirNext-Bold"
    static let medium = "AvenirNext-Medium"
    static let mono   = "Courier-Bold"

    static func display(for theme: Theme) -> String { theme.pixelated ? mono : bold }
    static func body(for theme: Theme) -> String    { theme.pixelated ? mono : medium }
}
