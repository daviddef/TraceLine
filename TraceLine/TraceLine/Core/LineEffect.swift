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
    /// The line dims toward its tail, brightest at the fingertip.
    ///
    /// This is the *look* of a disappearing tail without the mechanic: the points are all
    /// still there, so the tail still blocks and still counts. Actually removing it would
    /// be a different game — see ROADMAP § "The fading tail".
    case fade
    /// The whole line breathes, brightening and dimming.
    case pulse
    /// Bright dashes march along the line toward the fingertip.
    case chase
    /// Embers drift off the whole length of the line, not just the tip.
    case ember
    /// An unreliable neon tube: the line stutters now and then.
    case flicker

    /// True if the effect recolours the line itself. The doomed-tail warning is drawn over
    /// the line in the cutter's colour, and a line that is busy changing colour makes that
    /// warning hard to read — so recolouring effects are kept off cutter levels.
    var recolours: Bool { self == .prism }

    /// True if the effect varies the line's opacity. These fight the doomed-tail warning
    /// less than a hue shift does, but a line that is mid-dim when a cutter arrives is
    /// still harder to read, so they are kept off cutter levels too.
    var dims: Bool { self == .fade || self == .pulse || self == .flicker }

    /// True if the effect draws a dashed overlay along the line. The doomed-tail warning
    /// is *also* a dashed overlay, so the two read as the same language while meaning
    /// completely different things — spotted by putting them on one board and looking.
    var dashes: Bool { self == .chase }

    /// Effects that must not share a level with a cutter.
    var conflictsWithCutters: Bool { recolours || dims || dashes }
}
