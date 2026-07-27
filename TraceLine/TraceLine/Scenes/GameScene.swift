import SpriteKit

final class GameScene: SKScene {

    // MARK: - Configuration
    /// Mutable because endless swaps in a new board every wave.
    private(set) var levelConfig: LevelConfig
    let theme: Theme
    let mode: GameMode

    /// Endless only: which wave is on the board, and the score banked from earlier waves.
    private(set) var wave = 1
    private var bankedScore = 0

    // MARK: - Engine components
    private let stateMachine  = GameStateMachine()
    private let drawingEngine = DrawingEngine()

    // MARK: - Nodes
    private var lineNode: LineNode!
    private var hudNode: HUDNode!
    private var obstacleNodes: [ObstacleNode] = []
    private var pauseOverlay: SKNode?

    // MARK: - Game state
    private var timeRemaining: TimeInterval = 0
    private var score: Int = 0
    private var lastUpdateTime: TimeInterval = 0
    private var spawnTimer: TimeInterval = 0
    private var coverage: Float = 0

    /// Seconds actually spent drawing this round — the denominator for the measured
    /// sustained drawing speed the difficulty model has never been checked against.
    private var activeDrawTime: TimeInterval = 0

    /// Points per second the player actually sustained, distance drawn over time drawing.
    private var measuredDrawSpeed: Int {
        activeDrawTime > 0.2 ? Int(drawingEngine.totalDistance / CGFloat(activeDrawTime)) : 0
    }

    /// Two at once is already busy: each crosses the whole board.
    private static let maxConcurrentCutters = 2
    private static let maxConcurrentFuses = 1

    /// Shelters on this board, resolved from the level's normalised config.
    private var safeZones: [SafeZone] = []

    /// Held so a wave change can tear the board down and rebuild it.
    private var boardNodes: [SKNode] = []

    /// The flame drawn at the burning end of the line, while a fuse is alight.
    private var flameNode: SKEmitterNode?

    /// World 4's darkness veil, when the level is dark. Its torch follows the drawing tip.
    private var darknessNode: DarknessNode?

    /// A camera so the whole view can be shaken for impact. At the origin it changes
    /// nothing; a shake offsets it briefly.
    private let cameraNode = SKCameraNode()
    /// How fast the flame eats the line, in points per second. Slower than a player can
    /// draw, or it is a delayed death rather than a race.
    private static let flameSpeed: CGFloat = 190

    // MARK: - Play area
    private var playRect: CGRect = .zero

    #if DEBUG
    /// Forces a wave change every couple of seconds so the transition can actually be
    /// watched — a real one needs an unbroken drag that UI tests cannot produce.
    private var autoAdvancesWaves: Bool {
        CommandLine.arguments.contains("--debug-advance-waves")
    }
    private var autoAdvanceTimer: TimeInterval = 0
    #endif

    /// Screenshot mode: the board is posed, so nothing new should spawn or drift in.
    private var isDemoPath: Bool {
        #if DEBUG
        return CommandLine.arguments.contains("--demo-path")
        #else
        return false
        #endif
    }

    // MARK: - Init
    init(levelConfig: LevelConfig, theme: Theme, size: CGSize, mode: GameMode = .levels) {
        self.levelConfig = levelConfig
        self.theme = theme
        self.mode = mode
        super.init(size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used — scenes are built in code") }

    // MARK: - Scene lifecycle
    override func didMove(to view: SKView) {
        stateMachine.delegate = self
        setupPlayArea()      // before setupScene: the grid is drawn to fit the play area
        setupScene()
        setupHUD()
        timeRemaining = levelConfig.timeLimit

        #if DEBUG
        if CommandLine.arguments.contains("--demo-path") { seedDemoPath() }
        // Trip a fail on its own, to see the game-over overlay and auto-restart without
        // having to lose a round by hand.
        if CommandLine.arguments.contains("--debug-fail") {
            stateMachine.transition(to: .idle)
            run(.sequence([.wait(forDuration: 1.0),
                           .run { [weak self] in self?.triggerFail(reason: .obstacleHit) }]))
        }
        #endif
    }

    #if DEBUG
    /// Draws a representative round for App Store screenshots.
    ///
    /// The path is fed through the real DrawingEngine and drawn by the real LineNode,
    /// so what appears is genuine output — the engine would reject the path outright if
    /// it broke either rule. The scene stays in `.idle`, so nothing moves or fails while
    /// the screenshot is taken.
    private func seedDemoPath() {
        let inset: CGFloat = 28
        let rows = 8
        let spacing = (playRect.height - inset * 2) / CGFloat(rows - 1)

        var corners: [CGPoint] = []
        var y = playRect.maxY - inset
        var goingRight = true
        for _ in 0..<rows {
            let left = playRect.minX + inset, right = playRect.maxX - inset
            corners.append(CGPoint(x: goingRight ? left : right, y: y))
            corners.append(CGPoint(x: goingRight ? right : left, y: y))
            y -= spacing
            goingRight.toggle()
        }

        // A magnet goes down *before* the line is drawn, and the line is then drawn with
        // it in play, so what you see is genuinely bent rather than a straight path with a
        // field pasted next to it. It is placed off the serpentine's turns so the pull
        // bends the run without dragging it into the core.
        if levelConfig.obstacleTypes.contains(.magnetic) {
            let magnet = ObstacleNode(type: .magnetic, theme: theme)
            // Between two passes, not on one. With eight rows the midline falls exactly
            // between rows, so any half-spacing offset lands the magnet *on* a row and the
            // line simply draws into it.
            magnet.position = CGPoint(x: playRect.midX + playRect.width * 0.18,
                                      y: playRect.midY)
            magnet.fallSpeed = 0
            magnet.zPosition = 5
            obstacleNodes.append(magnet)
            addChild(magnet)
        }

        guard let start = corners.first else { return }
        drawingEngine.begin(at: start)
        // Walk between corners in small steps, the way real touch events arrive. If the
        // engine refuses a point, stop drawing and render what we have — bailing out of
        // the whole routine would skip the render and show an empty board.
        let live = obstacleDescriptors()
        walk: for i in 0..<(corners.count - 1) {
            let a = corners[i], b = corners[i + 1]
            let steps = max(1, Int(GeometryHelpers.distance(a, b) / 6))
            for s in 1...steps {
                let t = CGFloat(s) / CGFloat(steps)
                let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                if drawingEngine.extend(to: p, obstacles: live) != .ok { break walk }
            }
        }

        lineNode.update(points: drawingEngine.points)
        score = Int(drawingEngine.totalDistance * 2)
        hudNode.updateScore(score)
        hudNode.setHintVisible(false)
        coverage = drawingEngine.coveragePercent(in: playRect, gridSize: levelConfig.gridSize)
        hudNode.updateCoverage(coverage, targetFraction: levelConfig.targetCoverage,
                               barWidth: size.width - 48)
        hudNode.updateTimer(remaining: levelConfig.timeLimit * 0.55)

        // A cutter is posed deliberately across the line, because the doomed tail it
        // warns about is the point of the shot. Its lane crossing the path is legal —
        // unlike a lethal obstacle, a cutter touching the line does not end the round.
        if levelConfig.obstacleTypes.contains(.cutter) {
            let cutter = ObstacleNode(type: .cutter, theme: theme)
            cutter.position = CGPoint(x: playRect.midX + 40, y: playRect.midY - spacing / 2)
            cutter.startCrossing(direction: -1, speed: 0)
            cutter.zPosition = 6
            let lane = laneNode(atY: cutter.position.y)
            lane.alpha = 1
            cutter.laneNode = lane
            addChild(lane)
            obstacleNodes.append(cutter)
            addChild(cutter)
            updateDoomedTail()
        }

        // A fuse level poses a *burning* line: ignite it partway and advance the flame so
        // the screenshot catches the line mid-burn with the flame particle alight. Only
        // the type != .fuse filter below keeps a stray flame icon off the board.
        if levelConfig.obstacleTypes.contains(.fuse), drawingEngine.pointCount > 8 {
            let midX = playRect.midX
            drawingEngine.ignite(where: { a, b in
                GeometryHelpers.segmentsIntersect(a, b, CGPoint(x: midX, y: -1000),
                                                  CGPoint(x: midX, y: 1000))
            })
            drawingEngine.advanceBurn(distance: 90)
            lineNode.update(points: drawingEngine.points)
            showFlame()
        }

        // Pose the rest in the gaps between passes. A *lethal* obstacle touching the line
        // would mean the round had already ended, so a screenshot showing that misstates
        // the rules — keep those clear of the drawn path.
        // Seed with the magnet so nothing else is posed on top of it or inside its field.
        var placed: [CGPoint] = obstacleNodes.filter { $0.obstacleType == .magnetic }.map(\.position)
        for type in levelConfig.obstacleTypes.prefix(3) where type.isLethal && type != .magnetic {
            guard let spot = clearSpot(awayFrom: placed) else { continue }
            let obs = ObstacleNode(type: type, theme: theme)
            obs.position = spot
            obs.fallSpeed = 0
            obs.zPosition = 5
            obstacleNodes.append(obs)
            addChild(obs)
            placed.append(spot)
        }

        // Pose a hunter aimed at the tip, so a still shows the arrowhead locked onto its
        // prey. It does not home in demo mode, so it stays where it is posed.
        if levelConfig.obstacleTypes.contains(.hunter), let tip = drawingEngine.points.last {
            let h = ObstacleNode(type: .hunter, theme: theme)
            let spot = CGPoint(x: playRect.midX + 50, y: playRect.midY + 30)
            h.position = spot
            h.zRotation = atan2(tip.y - spot.y, tip.x - spot.x)
            h.zPosition = 5
            obstacleNodes.append(h)
            addChild(h)
        }

        // In the dark, pin the torch to the tip and pose one hazard inside it, so a still
        // shows the effect it is built around: a lit bubble revealing a hazard, the rest
        // of the placed hazards swallowed by the dark.
        if levelConfig.isDark, let tip = drawingEngine.points.last {
            darknessNode?.moveTorch(to: tip)
            let lit = ObstacleNode(type: .blocker, theme: theme)
            lit.position = CGPoint(x: tip.x + 46, y: tip.y + 30)
            lit.fallSpeed = 0
            lit.zPosition = 5
            obstacleNodes.append(lit)
            addChild(lit)
        }
    }

    /// Finds a point inside the play area that clears both the drawn line and any
    /// already-placed obstacle.
    private func clearSpot(awayFrom placed: [CGPoint]) -> CGPoint? {
        let fromLine: CGFloat = 46
        let fromEachOther: CGFloat = 110
        for _ in 0..<400 {
            let p = CGPoint(x: .random(in: playRect.minX + 40 ... playRect.maxX - 40),
                            y: .random(in: playRect.minY + 40 ... playRect.maxY - 40))
            let clearsLine = drawingEngine.points.allSatisfy {
                GeometryHelpers.distance($0, p) > fromLine
            }
            let clearsOthers = placed.allSatisfy { GeometryHelpers.distance($0, p) > fromEachOther }
            if clearsLine && clearsOthers { return p }
        }
        return nil
    }
    #endif

    private func setupPlayArea() {
        let inset: CGFloat = 24
        let topInset: CGFloat = 100     // below the HUD
        let bottomInset: CGFloat = 74   // above the coverage bar
        playRect = CGRect(
            x: -size.width / 2 + inset,
            y: -size.height / 2 + bottomInset,
            width:  size.width - inset * 2,
            height: size.height - topInset - bottomInset
        )
    }

    private func setupScene() {
        backgroundColor = theme.background
        camera = cameraNode
        addChild(cameraNode)
        addChild(BackgroundNode(theme: theme, size: size))
        buildBoard()
        lineNode = LineNode(theme: theme, effect: levelConfig.effect)
        lineNode.zPosition = 10
        addChild(lineNode)

        drawingEngine.wind = levelConfig.wind
        if levelConfig.hasWind { addWindIndicator() }

        if levelConfig.isDark {
            let dark = DarknessNode(sceneSize: size, theme: theme)
            dark.zPosition = 8          // over the board and hazards, under the self-lit line (10)
            dark.moveTorch(to: CGPoint(x: playRect.midX, y: playRect.midY))
            addChild(dark)
            darknessNode = dark
        }
    }

    /// A drifting streak field so the wind is visible before it bites — principle 3.
    private func addWindIndicator() {
        let dir = levelConfig.wind
        let mag = (dir.dx * dir.dx + dir.dy * dir.dy).squareRoot()
        guard mag > 0 else { return }
        let nx = dir.dx / mag, ny = dir.dy / mag

        let tint = theme.obstacleColors[ObstacleType.fuse.themeIndex]   // wind is World 3's, so wear its colour
        let field = SKNode()
        field.zPosition = 1
        for _ in 0..<22 {
            let streak = SKShapeNode(rectOf: CGSize(width: 34, height: 2), cornerRadius: 1)
            streak.fillColor = tint
            streak.strokeColor = .clear
            streak.zRotation = atan2(ny, nx)
            streak.position = CGPoint(x: .random(in: playRect.minX...playRect.maxX),
                                      y: .random(in: playRect.minY...playRect.maxY))
            let travel: CGFloat = 90
            let dur = Double.random(in: 1.0...1.6)
            streak.run(.repeatForever(.sequence([
                .group([.moveBy(x: nx * travel, y: ny * travel, duration: dur),
                        .sequence([.fadeAlpha(to: 0.5, duration: dur * 0.4),
                                   .fadeAlpha(to: 0, duration: dur * 0.6)])]),
                .run { [weak streak] in
                    streak?.position = CGPoint(x: .random(in: self.playRect.minX...self.playRect.maxX),
                                               y: .random(in: self.playRect.minY...self.playRect.maxY))
                },
            ])))
            field.addChild(streak)
        }
        addChild(field)
        boardNodes.append(field)
    }

    /// The grid and shelters for the current config. Rebuilt on every endless wave.
    private func buildBoard() {
        boardNodes.forEach { $0.removeFromParent() }
        boardNodes.removeAll()

        let grid = GridNode(theme: theme, playRect: playRect, gridSize: levelConfig.gridSize)
        addChild(grid)
        boardNodes.append(grid)

        safeZones = levelConfig.zones.map { $0.resolved(in: playRect) }
        for zone in safeZones {
            let node = SafeZoneNode(zone: zone, theme: theme)
            node.zPosition = 2      // above the grid, below the line and the hazards
            addChild(node)
            boardNodes.append(node)
        }
    }

    private func setupHUD() {
        hudNode = HUDNode(theme: theme, levelConfig: levelConfig, sceneSize: size)
        hudNode.zPosition = 100
        addChild(hudNode)
        if mode == .endless { hudNode.setWave(wave) }

        if theme.scanlines {
            let scanlines = ScanlineNode(size: size)
            scanlines.zPosition = 99   // under the HUD, so the pause button stays hittable
            addChild(scanlines)
        }
    }

    // MARK: - Main update loop
    override func update(_ currentTime: TimeInterval) {
        // A paused scene can produce a large first delta; clamp so nothing teleports.
        let rawDelta = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        let dt = min(rawDelta, 1.0 / 30.0)
        lastUpdateTime = currentTime

        guard stateMachine.phase == .drawing || stateMachine.phase == .idle else { return }

        // Obstacles. Hunters need to know where the tip is before they move. In a posed
        // demo they hold their placed position (and aim) rather than wandering off.
        let tip = drawingEngine.points.last
        for obs in obstacleNodes {
            if obs.obstacleType == .hunter && !isDemoPath { obs.huntTarget = tip }
            obs.update(dt: dt, playRect: playRect)
            obs.rebound(off: safeZones)
            if obs.isOffBoard(playRect) { recycleObstacle(obs) }
        }

        spawnTimer += dt
        if !isDemoPath, spawnTimer >= levelConfig.spawnInterval {
            spawnObstacle()
            spawnTimer = 0
        }

        // Demo mode poses a finished stroke but is meant to look like a round in
        // progress, so tip effects run there too — otherwise sparks never appear in a
        // screenshot and cannot be judged.
        lineNode.advance(dt: dt, isDrawing: stateMachine.phase == .drawing || isDemoPath)

        // In the dark, the torch rides the drawing tip; before a stroke starts it waits
        // at the board's centre where the line will begin.
        if let darknessNode, let tip = drawingEngine.points.last {
            darknessNode.moveTorch(to: tip)
        }

        #if DEBUG
        if mode == .endless, autoAdvancesWaves, drawingEngine.pointCount >= 2 {
            autoAdvanceTimer += dt
            if autoAdvanceTimer >= 2.0 { autoAdvanceTimer = 0; advanceWave() }
        }
        #endif

        guard stateMachine.phase == .drawing else { return }

        activeDrawTime += dt      // time actually spent drawing, for the measured speed

        applyCutters()
        updateDoomedTail()
        if case .fail = applyFuses(dt: dt) {
            triggerFail(reason: .burnedOut)
            return
        }

        // An obstacle can fall onto a finger that isn't moving, so the tip is
        // re-checked every frame and not only on touchesMoved.
        if case .fail(let reason) = drawingEngine.checkTipCollision(obstacles: obstacleDescriptors()) {
            triggerFail(reason: reason)
            return
        }

        // Countdown
        timeRemaining -= dt
        hudNode.updateTimer(remaining: max(0, timeRemaining))
        if timeRemaining <= 0 {
            triggerFail(reason: .timeExpired)
            return
        }

        // Coverage + win check
        coverage = drawingEngine.coveragePercent(in: playRect, gridSize: levelConfig.gridSize)
        hudNode.updateCoverage(coverage,
                               targetFraction: levelConfig.targetCoverage,
                               barWidth: size.width - 48)
        if coverage >= levelConfig.targetCoverage {
            switch mode {
            case .levels:  triggerWin(coverage: coverage)
            case .endless: advanceWave()
            }
        }
    }

    // MARK: - Touch handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let pos = touch.location(in: self)

        if stateMachine.phase == .paused {
            handlePauseTouch(at: pos)
            return
        }
        guard stateMachine.phase == .idle else { return }

        if let name = atPoint(pos).name, name == "pause_button" {
            stateMachine.transition(to: .paused)
            return
        }

        guard playRect.contains(pos) else { return }
        drawingEngine.begin(at: pos)
        lineNode.update(points: drawingEngine.points)
        hudNode.setHintVisible(false)
        stateMachine.transition(to: .drawing)
        Analytics.log(.levelStarted(id: levelConfig.id))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard stateMachine.phase == .drawing, let touch = touches.first else { return }

        // The finger is free to wander outside the play area; the line stops at the
        // edge rather than ending the round, since leaving the board isn't a listed
        // fail condition.
        let pos = clampToPlayArea(touch.location(in: self))

        switch drawingEngine.extend(to: pos, obstacles: obstacleDescriptors()) {
        case .ok:
            lineNode.update(points: drawingEngine.points)
            score = bankedScore + Int(drawingEngine.totalDistance * 2)
            hudNode.updateScore(score)
        case .fail(let reason):
            triggerFail(reason: reason)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard stateMachine.phase == .drawing else { return }
        triggerFail(reason: .fingerLifted)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func clampToPlayArea(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.x, playRect.minX), playRect.maxX),
                y: min(max(point.y, playRect.minY), playRect.maxY))
    }

    /// Cutters sever the line where they cross it, keeping only the piece still held by
    /// the finger. Coverage is recomputed from the surviving points, so the bar retracts
    /// on its own and the player watches the loss happen.
    private func applyCutters() {
        let cutters = obstacleNodes.filter { $0.obstacleType.severs }
        guard !cutters.isEmpty, drawingEngine.pointCount >= 2 else { return }

        var didCut = false
        for cutter in cutters {
            let descriptor = cutter.descriptor()
            if drawingEngine.cut(where: { a, b in
                descriptor.intersectsSegment(from: a, to: b) && !isSheltered(from: a, to: b)
            }) {
                didCut = true
            }
        }
        guard didCut else { return }

        lineNode.update(points: drawingEngine.points)
        Haptics.cut()
        shake(power: 6)
    }

    /// Marks the stretch of line the cutters are going to take, live, while the player
    /// draws. Without it the cut is the first news you get, and losing half a board with
    /// no warning reads as the game stealing from you rather than as a bad bet.
    /// The lane was always visible; the *consequence* was not.
    /// Line tucked inside a shelter is out of reach. Only a segment wholly inside counts:
    /// anything poking out is exposed, and the cut and the warning must agree on that.
    private func isSheltered(from a: CGPoint, to b: CGPoint) -> Bool {
        safeZones.contains { $0.shelters(from: a, to: b) }
    }

    private func updateDoomedTail() {
        var doomed = 0
        for cutter in obstacleNodes where cutter.obstacleType.severs {
            guard let sweep = cutter.remainingSweep(in: playRect, zones: safeZones) else { continue }
            // The same hit test the cut uses, over the lane the cutter has yet to
            // travel — so the warning and the cut can never disagree.
            let region = ObstacleDescriptor(id: cutter.hash, shape: .rect(sweep), severs: true)
            doomed = max(doomed, drawingEngine.doomedCount(where: { a, b in
                region.intersectsSegment(from: a, to: b) && !self.isSheltered(from: a, to: b)
            }))
        }
        lineNode.markDoomed(points: drawingEngine.points, engineCount: doomed,
                            color: theme.obstacleColors[ObstacleType.cutter.themeIndex])
    }

    /// The Fuse: contact ignites the line rather than ending the round, and a flame then
    /// eats toward the fingertip until the player reaches a shelter. Everything but the
    /// flame visual is engine work already built and tested.
    private func applyFuses(dt: TimeInterval) -> DrawResult {
        if !drawingEngine.isBurning {
            for fuse in obstacleNodes where fuse.obstacleType.ignites {
                let d = fuse.descriptor()
                if drawingEngine.ignite(where: { d.intersectsSegment(from: $0, to: $1) }) {
                    recycleObstacle(fuse)          // the fuse is spent once it lights the line
                    lineNode.update(points: drawingEngine.points)
                    Haptics.fail()                 // a heavier cue than a cut: you are now in trouble
                    shake(power: 10)
                    showFlame()
                    break
                }
            }
            return .ok
        }

        // Already burning. Reaching shelter with the tip puts it out.
        if let tip = drawingEngine.currentTip, safeZones.contains(where: { $0.contains(tip) }) {
            drawingEngine.extinguish()
            hideFlame()
            return .ok
        }

        switch drawingEngine.advanceBurn(distance: Self.flameSpeed * CGFloat(dt)) {
        case .reachedTheTip:
            hideFlame()
            return .fail(.burnedOut)
        case .burning:
            lineNode.update(points: drawingEngine.points)
            flameNode?.position = drawingEngine.burnFront ?? .zero
            return .ok
        case .notBurning:
            return .ok
        }
    }

    private func showFlame() {
        guard flameNode == nil else { return }
        let fire = SKEmitterNode()
        fire.particleTexture = LineNode.softDot
        fire.particleBirthRate = 220
        fire.particleLifetime = 0.5
        fire.particleLifetimeRange = 0.3
        fire.particleSize = CGSize(width: 14, height: 14)
        fire.particleScaleSpeed = -1.4
        fire.particleAlphaSpeed = -1.8
        fire.particleSpeed = 40
        fire.particleSpeedRange = 40
        fire.emissionAngleRange = .pi * 2
        fire.particleColor = theme.obstacleColors[ObstacleType.fuse.themeIndex]
        fire.particleColorBlendFactor = 1
        fire.particleBlendMode = .add
        fire.zPosition = 12
        fire.targetNode = self
        fire.position = drawingEngine.burnFront ?? .zero
        addChild(fire)
        flameNode = fire
    }

    /// A brief camera shake. `power` is the peak offset in points. Suppressed entirely
    /// when the player (or the system) has asked to reduce motion.
    private func shake(power: CGFloat) {
        guard !Motion.isReduced else { return }
        cameraNode.removeAction(forKey: "shake")
        var steps: [SKAction] = []
        var p = power
        while p > 0.5 {
            steps.append(.move(to: CGPoint(x: .random(in: -p...p), y: .random(in: -p...p)),
                               duration: 0.035))
            p *= 0.72
        }
        steps.append(.move(to: .zero, duration: 0.04))
        cameraNode.run(.sequence(steps), withKey: "shake")
    }

    /// A ring of particles thrown from a point — used on a clear and a wave advance.
    private func burst(at point: CGPoint, color: SKColor) {
        let b = SKEmitterNode()
        b.particleTexture = LineNode.softDot
        b.numParticlesToEmit = 40
        b.particleBirthRate = 2000
        b.particleLifetime = 0.6
        b.particleLifetimeRange = 0.3
        b.particleSize = CGSize(width: 10, height: 10)
        b.particleScaleSpeed = -1.4
        b.particleAlphaSpeed = -1.6
        b.particleSpeed = 260
        b.particleSpeedRange = 120
        b.emissionAngleRange = .pi * 2
        b.particleColor = color
        b.particleColorBlendFactor = 1
        b.particleBlendMode = .add
        b.position = point
        b.zPosition = 20
        addChild(b)
        b.run(.sequence([.wait(forDuration: 1.0), .removeFromParent()]))
    }

    private func hideFlame() {
        flameNode?.particleBirthRate = 0
        flameNode?.run(.sequence([.wait(forDuration: 0.5), .removeFromParent()]))
        flameNode = nil
    }

    private func obstacleDescriptors() -> [ObstacleDescriptor] {
        obstacleNodes.map { $0.descriptor() }
    }

    // MARK: - Round score
    private func makeRoundScore(stars: Int) -> RoundScore {
        RoundScore(baseDistance: drawingEngine.totalDistance
                                 + CGFloat(bankedScore) / 2,   // banked waves, in distance terms
                   coveragePct: coverage,
                   timeRemaining: max(0, timeRemaining),
                   nearMissCount: drawingEngine.nearMissCount,
                   starsEarned: stars)
    }

    // MARK: - Fail
    private func triggerFail(reason: FailReason) {
        guard stateMachine.phase == .drawing || stateMachine.phase == .idle else { return }
        stateMachine.transition(to: .failFlash, failReason: reason)
        Haptics.fail()

        if mode == .endless {
            GameCenter.submitEndless(score: score, wave: wave)
        }
        Analytics.log(.levelFailed(id: levelConfig.id, reason: reason,
                                   coveragePercent: Int(coverage * 100),
                                   drawSpeed: measuredDrawSpeed))
        lineNode.triggerFail { [weak self] in
            guard let self else { return }
            self.showFailOverlayAndRestart(reason: reason)
        }
    }

    /// A game-over that does not stop the game. Instead of a full screen with a "Try Again"
    /// button — which the round's own tempo makes tedious — a light overlay shows what went
    /// wrong over the frozen board, then the level restarts on its own. The way *out* is the
    /// pause button, which is always there before a stroke begins.
    private func showFailOverlayAndRestart(reason: FailReason) {
        let overlay = SKNode()
        overlay.zPosition = 250

        // Deliberately translucent — the board stays visible behind it.
        let dim = SKShapeNode(rectOf: size)
        dim.fillColor = theme.background.withAlphaComponent(0.6)
        dim.strokeColor = .clear
        overlay.addChild(dim)

        let title = SKLabelNode(fontNamed: Fonts.display(for: theme))
        title.text = "Game Over"
        title.fontSize = 34
        title.fontColor = theme.hudTextColor
        title.position = CGPoint(x: 0, y: 40)
        overlay.addChild(title)

        let reasonLabel = SKLabelNode(fontNamed: Fonts.body(for: theme))
        reasonLabel.text = reason.quip
        reasonLabel.fontSize = 16
        reasonLabel.fontColor = theme.hudTextColor.withAlphaComponent(0.8)
        reasonLabel.position = CGPoint(x: 0, y: 2)
        overlay.addChild(reasonLabel)

        let hint = SKLabelNode(fontNamed: Fonts.body(for: theme))
        hint.text = "Restarting…"
        #if DEBUG
        // A live check of the difficulty model's ~400 pt/s assumption against what was
        // actually drawn. DEBUG only — it never reaches a player.
        if measuredDrawSpeed > 0 { hint.text = "Restarting…   ·   drew \(measuredDrawSpeed) pt/s" }
        #endif
        hint.fontSize = 13
        hint.fontColor = theme.hudTextColor.withAlphaComponent(0.45)
        hint.position = CGPoint(x: 0, y: -34)
        overlay.addChild(hint)

        overlay.alpha = 0
        overlay.run(.fadeIn(withDuration: 0.2))
        addChild(overlay)

        // Restart the level on its own after a beat, no tap required.
        run(.sequence([.wait(forDuration: 1.3), .run { [weak self] in
            self?.restartCurrentLevel()
        }]))
    }

    // MARK: - Endless waves

    /// The board is full, so it clears and the next one steps up — **without the finger
    /// leaving the glass**. The line restarts from wherever the player already is, which
    /// is what makes a whole run one unbroken stroke rather than a series of attempts.
    private func advanceWave() {
        bankedScore += Int(drawingEngine.totalDistance * 2)
            + Endless.waveBonus(wave: wave, timeRemaining: timeRemaining)
        wave += 1
        levelConfig = Endless.config(forWave: wave)

        // Clear the board.
        obstacleNodes.forEach { recycleObstacle($0) }
        spawnTimer = 0
        timeRemaining = levelConfig.timeLimit
        buildBoard()

        // Keep drawing from where the finger already is.
        let tip = drawingEngine.currentTip ?? .zero
        drawingEngine.begin(at: tip)
        lineNode.reset()
        lineNode.update(points: drawingEngine.points)

        coverage = 0
        hudNode.setWave(wave)
        hudNode.updateScore(bankedScore)
        hudNode.updateCoverage(0, targetFraction: levelConfig.targetCoverage,
                               barWidth: size.width - 48)
        hudNode.resetTimer(to: levelConfig.timeLimit)
        Haptics.win()
        burst(at: drawingEngine.currentTip ?? .zero, color: theme.hudAccentColor)
        shake(power: 5)
        flashWaveBanner()
    }

    private func flashWaveBanner() {
        let banner = SKLabelNode(fontNamed: Fonts.display(for: theme))
        banner.text = "WAVE \(wave)"
        banner.fontSize = 40
        banner.fontColor = theme.hudAccentColor
        banner.verticalAlignmentMode = .center
        banner.zPosition = 150
        banner.alpha = 0
        addChild(banner)
        banner.run(.sequence([
            .group([.fadeAlpha(to: 0.95, duration: 0.18), .scale(to: 1.15, duration: 0.18)]),
            .wait(forDuration: 0.35),
            .group([.fadeOut(withDuration: 0.4), .scale(to: 1.6, duration: 0.4)]),
            .removeFromParent(),
        ]))
    }

    // MARK: - Win
    private func triggerWin(coverage: Float) {
        stateMachine.transition(to: .levelComplete)
        spawnTimer = 0
        Haptics.win()

        burst(at: drawingEngine.currentTip ?? .zero, color: SKColor(hex: "#22c55e"))
        shake(power: 5)
        let stars = starsEarned(coverage: coverage)
        let roundScore = makeRoundScore(stars: stars)
        PlayerProgress.shared.recordCompletion(levelId: levelConfig.id,
                                               stars: stars,
                                               score: roundScore.total)
        GameCenter.submit(score: roundScore.total)
        GameCenter.reportCompletion(levelsCleared: PlayerProgress.shared.completedLevelCount,
                                    timeRemaining: timeRemaining)
        Analytics.log(.levelCleared(id: levelConfig.id, score: roundScore.total, stars: stars,
                                    secondsRemaining: Int(max(0, timeRemaining)),
                                    drawSpeed: measuredDrawSpeed))

        run(.wait(forDuration: 0.6)) { [weak self] in
            guard let self, let view = self.view else { return }
            let scene = WinScene(roundScore: roundScore,
                                 levelConfig: self.levelConfig,
                                 theme: self.theme,
                                 size: self.size)
            view.presentScene(scene, transition: .fade(withDuration: 0.4))
        }
    }

    private func starsEarned(coverage: Float) -> Int {
        if coverage >= levelConfig.targetCoverage + 0.15 &&
           timeRemaining > 10 && drawingEngine.nearMissCount == 0 { return 3 }
        if timeRemaining > 10 { return 2 }
        return 1
    }

    // MARK: - Obstacles
    /// Obstacles still on the board that end the round on contact. Cutters are excluded:
    /// they cross and leave within a couple of seconds, whereas a blocker sits there for
    /// most of the round.
    private var lethalObstacleCount: Int {
        obstacleNodes.filter { $0.obstacleType.isLethal }.count
    }

    private var fuseCount: Int {
        obstacleNodes.filter { $0.obstacleType.ignites }.count
    }

    private var cutterCount: Int {
        obstacleNodes.filter { $0.obstacleType.severs }.count
    }

    private func spawnObstacle() {
        guard let type = levelConfig.obstacleTypes.randomElement() else { return }

        if type == .cutter {
            // Budgeted separately from `maxObstacles`. Sharing that cap meant a board
            // full of slow blockers starved cutters out entirely — they never appeared.
            guard cutterCount < Self.maxConcurrentCutters else { return }
            return spawnCutter()
        }

        if type == .fuse {
            // One burn at a time: it is already a full-attention event, and it must not
            // ignite while the line is still burning from the last one.
            guard fuseCount < Self.maxConcurrentFuses, !drawingEngine.isBurning else { return }
        }

        guard lethalObstacleCount < levelConfig.maxObstacles else { return }

        if type == .hunter { return spawnHunter() }

        let obs = ObstacleNode(type: type, theme: theme)

        // Spec: keep at least 60pt between obstacles at spawn. Try a handful of
        // positions and skip this spawn if the top of the board is already busy.
        guard let x = findSpawnX() else { return }
        obs.position = CGPoint(x: x, y: playRect.maxY + 30)
        obs.fallSpeed = 60 + CGFloat(levelConfig.id) * 3
        obs.startFalling(in: playRect.width)
        obs.zPosition = 5
        obstacleNodes.append(obs)
        addChild(obs)
    }

    /// A hunter enters at the top of the board and then steers toward the drawing tip
    /// every frame (see the update loop). It enters where a faller would, so it is on
    /// screen and telegraphed before it starts closing in.
    private func spawnHunter() {
        guard let x = findSpawnX() else { return }
        let obs = ObstacleNode(type: .hunter, theme: theme)
        obs.position = CGPoint(x: x, y: playRect.maxY - 20)
        obs.zPosition = 5
        obstacleNodes.append(obs)
        addChild(obs)
    }

    /// A cutter runs a horizontal lane. The lane is drawn first and the cutter enters
    /// from off-board, so the hazard is on screen before it can take anything — the
    /// player has to be able to see the trap before it springs.
    private func spawnCutter() {
        let inset = ObstacleNode.cutterSize.height
        let y = CGFloat.random(in: playRect.minY + inset ... playRect.maxY - inset)
        let leftToRight = Bool.random()

        let obs = ObstacleNode(type: .cutter, theme: theme)
        obs.position = CGPoint(x: leftToRight ? playRect.minX - ObstacleNode.cutterSize.width
                                              : playRect.maxX + ObstacleNode.cutterSize.width,
                               y: y)
        obs.startCrossing(direction: leftToRight ? 1 : -1,
                          speed: 110 + CGFloat(levelConfig.id) * 6)
        obs.zPosition = 6

        let lane = laneNode(atY: y)
        obs.laneNode = lane
        addChild(lane)

        obstacleNodes.append(obs)
        addChild(obs)
    }

    /// The visible track a cutter will run along.
    private func laneNode(atY y: CGFloat) -> SKNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: playRect.minX, y: y))
        path.addLine(to: CGPoint(x: playRect.maxX, y: y))

        let lane = SKShapeNode(path: path)
        lane.strokeColor = theme.obstacleColors[ObstacleType.cutter.themeIndex]
            .withAlphaComponent(0.35)
        lane.lineWidth = 1.5
        lane.lineCap = .round
        lane.zPosition = 4
        // Dashes read as a track rather than as part of anyone's drawing.
        lane.path = path.copy(dashingWithPhase: 0, lengths: [8, 7])
        lane.alpha = 0
        lane.run(.fadeIn(withDuration: 0.25))
        return lane
    }

    private func findSpawnX() -> CGFloat? {
        let minSpacing: CGFloat = 60
        let recent = obstacleNodes.filter { $0.position.y > playRect.maxY - minSpacing }
        for _ in 0..<8 {
            let x = CGFloat.random(in: playRect.minX + 20 ... playRect.maxX - 20)
            if recent.allSatisfy({ abs($0.position.x - x) >= minSpacing }) { return x }
        }
        return nil
    }

    private func recycleObstacle(_ obs: ObstacleNode) {
        if let lane = obs.laneNode {
            lane.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
        }
        obs.removeFromParent()
        obstacleNodes.removeAll { $0 === obs }
    }
}

// MARK: - GameStateMachineDelegate
extension GameScene: GameStateMachineDelegate {
    func stateMachine(_ machine: GameStateMachine,
                      didTransitionFrom old: GamePhase,
                      to new: GamePhase) {
        switch new {
        case .paused: showPauseOverlay()
        case .idle, .drawing: hidePauseOverlay()
        default: break
        }
    }

    private func showPauseOverlay() {
        guard pauseOverlay == nil else { return }
        let overlay = SKNode()
        overlay.zPosition = 200

        let dim = SKShapeNode(rectOf: size)
        dim.fillColor = theme.background.withAlphaComponent(0.85)
        dim.strokeColor = .clear
        overlay.addChild(dim)

        let title = SKLabelNode(fontNamed: Fonts.display(for: theme))
        title.text = "Paused"
        title.fontSize = 32
        title.fontColor = theme.hudTextColor
        title.position = CGPoint(x: 0, y: 140)
        overlay.addChild(title)

        overlay.addChild(ButtonNode(title: "Resume", theme: theme, name: "resume_button",
                                    position: CGPoint(x: 0, y: 60)))
        // Endless has no single level to retry, so it offers a fresh run instead.
        overlay.addChild(ButtonNode(title: mode == .endless ? "New Run" : "Restart Level",
                                    theme: theme, name: "restart_button",
                                    position: CGPoint(x: 0, y: -6), isPrimary: false))
        if mode != .endless {
            overlay.addChild(ButtonNode(title: "Level Select", theme: theme, name: "levels_button",
                                        position: CGPoint(x: 0, y: -72), isPrimary: false))
        }
        overlay.addChild(ButtonNode(title: "Home", theme: theme, name: "home_button",
                                    position: CGPoint(x: 0, y: mode == .endless ? -72 : -138),
                                    isPrimary: false))

        addChild(overlay)
        pauseOverlay = overlay
    }

    private func hidePauseOverlay() {
        pauseOverlay?.removeFromParent()
        pauseOverlay = nil
    }

    private func handlePauseTouch(at pos: CGPoint) {
        switch atPoint(pos).name {
        case "resume_button":
            stateMachine.transition(to: .idle)
        case "restart_button":
            restartCurrentLevel()
        case "levels_button":
            let scene = LevelSelectScene(theme: theme, size: size, worldID: levelConfig.world)
            view?.presentScene(scene, transition: .fade(withDuration: 0.3))
        case "home_button":
            view?.presentScene(HomeScene(theme: theme, size: size),
                               transition: .fade(withDuration: 0.3))
        default:
            break
        }
    }

    /// Starts this level (or, in endless, a fresh run) over from the beginning.
    private func restartCurrentLevel() {
        let fresh: GameScene
        if mode == .endless {
            fresh = GameScene(levelConfig: Endless.config(forWave: 1), theme: theme,
                              size: size, mode: .endless)
        } else {
            let base = LevelConfig.level(id: levelConfig.id) ?? levelConfig
            fresh = GameScene(levelConfig: base, theme: theme, size: size, mode: mode)
        }
        view?.presentScene(fresh, transition: .fade(withDuration: 0.3))
    }
}
