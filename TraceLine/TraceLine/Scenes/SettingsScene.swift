import SpriteKit

/// Sound and accessibility preferences. Kept intentionally small — two switches and a
/// way back — because everything here should be discoverable at a glance, not a menu to
/// get lost in.
final class SettingsScene: SKScene {

    private let theme: Theme
    private var rows: [ToggleRow] = []

    init(theme: Theme, size: CGSize) {
        self.theme = theme
        super.init(size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used — scenes are built in code") }

    override func didMove(to view: SKView) {
        backgroundColor = theme.background
        addChild(BackgroundNode(theme: theme, size: size))

        let title = SKLabelNode(fontNamed: Fonts.display(for: theme))
        title.text = "Settings"
        title.fontSize = 40
        title.fontColor = theme.lineColor
        title.position = CGPoint(x: 0, y: size.height / 2 - 130)
        addChild(title)

        // Each row owns a getter/setter pair so the scene never caches stale state.
        let specs: [(String, String, () -> Bool, (Bool) -> Void)] = [
            ("Sound effects", "toggle_sound",
             { PlayerProgress.shared.soundEnabled },
             { PlayerProgress.shared.soundEnabled = $0 }),
            ("Reduce motion", "toggle_motion",
             { PlayerProgress.shared.reduceMotion },
             { PlayerProgress.shared.reduceMotion = $0 }),
            ("Glow", "toggle_glow",
             { PlayerProgress.shared.glowEnabled },
             { PlayerProgress.shared.glowEnabled = $0 }),
        ]

        var y: CGFloat = 60
        for (label, name, get, set) in specs {
            let row = ToggleRow(label: label, name: name, isOn: get(), theme: theme,
                                width: min(320, size.width - 60))
            row.position = CGPoint(x: 0, y: y)
            row.onChange = set
            addChild(row)
            rows.append(row)
            y -= 84
        }

        // A one-line explanation under the motion switch — it isn't self-evident what it does.
        let note = SKLabelNode(fontNamed: Fonts.body(for: theme))
        note.text = "Reduce motion also follows your iPhone's accessibility setting."
        note.fontSize = 11
        note.fontColor = theme.hudTextColor.withAlphaComponent(0.45)
        note.position = CGPoint(x: 0, y: y + 8)
        note.preferredMaxLayoutWidth = size.width - 60
        note.numberOfLines = 2
        note.verticalAlignmentMode = .center
        addChild(note)

        addChild(ButtonNode(title: "Back", theme: theme, name: "back_button",
                            position: CGPoint(x: 0, y: -size.height / 2 + 130), isPrimary: false))

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let versionLabel = SKLabelNode(fontNamed: Fonts.body(for: theme))
        versionLabel.text = "TraceLine \(version)"
        versionLabel.fontSize = 11
        versionLabel.fontColor = theme.hudTextColor.withAlphaComponent(0.35)
        versionLabel.position = CGPoint(x: 0, y: -size.height / 2 + 60)
        addChild(versionLabel)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pos = touches.first?.location(in: self),
              let name = atPoint(pos).name else { return }

        if name == "back_button" {
            Haptics.tap()
            view?.presentScene(HomeScene(theme: theme, size: size),
                               transition: .fade(withDuration: 0.3))
            return
        }

        if let row = rows.first(where: { $0.name == name }) {
            row.toggle()
            Haptics.tap()   // the tap cue itself demonstrates the sound switch's effect
        }
    }
}

/// A labelled on/off switch drawn in code. Every child carries the row's `name`, so
/// `atPoint(_:)` reports the row no matter which part of it was touched.
final class ToggleRow: SKNode {

    private let theme: Theme
    private let track: SKShapeNode
    private let knob: SKShapeNode
    private(set) var isOn: Bool
    var onChange: ((Bool) -> Void)?

    private let trackWidth: CGFloat = 52
    private let trackHeight: CGFloat = 30

    init(label: String, name: String, isOn: Bool, theme: Theme, width: CGFloat) {
        self.theme = theme
        self.isOn = isOn
        track = SKShapeNode(rectOf: CGSize(width: trackWidth, height: trackHeight),
                            cornerRadius: trackHeight / 2)
        knob = SKShapeNode(circleOfRadius: trackHeight / 2 - 4)
        super.init()
        self.name = name

        // A hit target spanning the whole row, so a tap anywhere on the line registers.
        let hit = SKShapeNode(rectOf: CGSize(width: width, height: 56), cornerRadius: 12)
        hit.fillColor = theme.hudTextColor.withAlphaComponent(0.04)
        hit.strokeColor = .clear
        hit.name = name
        addChild(hit)

        let text = SKLabelNode(fontNamed: Fonts.body(for: theme))
        text.text = label
        text.fontSize = 17
        text.fontColor = theme.hudTextColor
        text.horizontalAlignmentMode = .left
        text.verticalAlignmentMode = .center
        text.position = CGPoint(x: -width / 2 + 20, y: 0)
        text.name = name
        addChild(text)

        track.strokeColor = .clear
        track.position = CGPoint(x: width / 2 - trackWidth / 2 - 20, y: 0)
        track.name = name
        addChild(track)

        knob.strokeColor = .clear
        knob.fillColor = .white
        knob.name = name
        track.addChild(knob)

        render(animated: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used — scenes are built in code") }

    func toggle() {
        isOn.toggle()
        render(animated: true)
        onChange?(isOn)
    }

    private func render(animated: Bool) {
        let onX = trackWidth / 2 - knob.frame.width / 2 - 3
        let target = CGPoint(x: isOn ? onX : -onX, y: 0)
        let fill = isOn ? theme.hudAccentColor : theme.hudTextColor.withAlphaComponent(0.22)
        if animated {
            knob.run(.move(to: target, duration: 0.12))
            track.run(.customAction(withDuration: 0.12) { [weak self] _, _ in
                self?.track.fillColor = fill
            })
        } else {
            knob.position = target
            track.fillColor = fill
        }
    }
}
