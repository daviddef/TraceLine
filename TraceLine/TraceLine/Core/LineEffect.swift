import SpriteKit

/// A per-level flourish on the drawn line. Cosmetic only — no effect touches the points
/// array, so none of them can change coverage, crossing, or what a cutter takes. Anything
/// that altered the line's *behaviour* would belong in DrawingEngine and would need to be
/// telegraphed; these are pure decoration and safe to vary.
///
/// Assigned per level in levels.json rather than rolled at runtime. A level looks the same
/// every time you come back to it, which is what makes an effect read as that level's
/// signature instead of a rendering glitch.
enum LineEffect: String, Codable, CaseIterable {
    /// The theme's own line, unadorned.
    case plain
    /// Hue drifts along the line's length — a rainbow that travels as you draw.
    case prism
    /// Embers thrown from the drawing tip.
    case spark
    /// A bright pulse that runs the length of the drawn path and repeats.
    case comet

    /// True if the effect recolours the line itself. The doomed-tail warning is drawn over
    /// the line in the cutter's colour, and a line that is busy changing colour makes that
    /// warning hard to read — so recolouring effects are kept off cutter levels.
    var recolours: Bool { self == .prism }
}
