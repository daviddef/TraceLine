import SpriteKit

final class GameScene: SKScene {

    // MARK: - Configuration
    let levelConfig: LevelConfig
    let theme: Theme

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

    /// Two at once is already busy: each crosses the whole board.
    private static let maxConcurrentCutters = 2

    // MARK: - Play area
    private var playRect: CGRect = .zero

    /// Screenshot mode: the board is posed, so nothing new should spawn or drift in.
    private var isDemoPath: Bool {
        #if DEBUG
        return CommandLine.arguments.contains("--demo-path")
        #else
        return false
        #endif
    }

    // MARK: - Init
    init(levelConfig: LevelConfig, theme: Theme, size: CGSize) {
        self.levelConfig = levelConfig
        self.theme = theme
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

        guard let start = corners.first else { return }
        drawingEngine.begin(at: start)
        // Walk between corners in small steps, the way real touch events arrive.
        for i in 0..<(corners.count - 1) {
            let a = corners[i], b = corners[i + 1]
            let steps = max(1, Int(GeometryHelpers.distance(a, b) / 6))
            for s in 1...steps {
                let t = CGFloat(s) / CGFloat(steps)
                let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                guard drawingEngine.extend(to: p, obstacles: []) == .ok else { return }
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

        // Pose the rest in the gaps between passes. A *lethal* obstacle touching the line
        // would mean the round had already ended, so a screenshot showing that misstates
        // the rules — keep those clear of the drawn path.
        var placed: [CGPoint] = []
        for type in levelConfig.obstacleTypes.prefix(2) where !type.severs {
            guard let spot = clearSpot(awayFrom: placed) else { continue }
            let obs = ObstacleNode(type: type, theme: theme)
            obs.position = spot
            obs.fallSpeed = 0
            obs.zPosition = 5
            obstacleNodes.append(obs)
            addChild(obs)
            placed.append(spot)
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
        addChild(GridNode(theme: theme, playRect: playRect, gridSize: levelConfig.gridSize))
        lineNode = LineNode(theme: theme)
        lineNode.zPosition = 10
        addChild(lineNode)
    }

    private func setupHUD() {
        hudNode = HUDNode(theme: theme, levelConfig: levelConfig, sceneSize: size)
        hudNode.zPosition = 100
        addChild(hudNode)
    }

    // MARK: - Main update loop
    override func update(_ currentTime: TimeInterval) {
        // A paused scene can produce a large first delta; clamp so nothing teleports.
        let rawDelta = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        let dt = min(rawDelta, 1.0 / 30.0)
        lastUpdateTime = currentTime

        guard stateMachine.phase == .drawing || stateMachine.phase == .idle else { return }

        // Obstacles
        for obs in obstacleNodes {
            obs.update(dt: dt, playRect: playRect)
            if obs.isOffBoard(playRect) { recycleObstacle(obs) }
        }

        spawnTimer += dt
        if !isDemoPath, spawnTimer >= levelConfig.spawnInterval {
            spawnObstacle()
            spawnTimer = 0
        }

        guard stateMachine.phase == .drawing else { return }

        applyCutters()
        updateDoomedTail()

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
            triggerWin(coverage: coverage)
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
            score = Int(drawingEngine.totalDistance * 2)
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
            if drawingEngine.cut(where: { descriptor.intersectsSegment(from: $0, to: $1) }) {
                didCut = true
            }
        }
        guard didCut else { return }

        lineNode.update(points: drawingEngine.points)
        Haptics.cut()
    }

    /// Marks the stretch of line the cutters are going to take, live, while the player
    /// draws. Without it the cut is the first news you get, and losing half a board with
    /// no warning reads as the game stealing from you rather than as a bad bet.
    /// The lane was always visible; the *consequence* was not.
    private func updateDoomedTail() {
        var doomed = 0
        for cutter in obstacleNodes where cutter.obstacleType.severs {
            guard let sweep = cutter.remainingSweep(in: playRect) else { continue }
            // The same hit test the cut uses, over the lane the cutter has yet to
            // travel — so the warning and the cut can never disagree.
            let region = ObstacleDescriptor(id: cutter.hash, shape: .rect(sweep), severs: true)
            doomed = max(doomed, drawingEngine.doomedCount(where: {
                region.intersectsSegment(from: $0, to: $1)
            }))
        }
        lineNode.markDoomed(engineCount: doomed,
                            color: theme.obstacleColors[ObstacleType.cutter.themeIndex])
    }

    private func obstacleDescriptors() -> [ObstacleDescriptor] {
        obstacleNodes.map { $0.descriptor() }
    }

    // MARK: - Round score
    private func makeRoundScore(stars: Int) -> RoundScore {
        RoundScore(baseDistance: drawingEngine.totalDistance,
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

        let roundScore = makeRoundScore(stars: 0)
        Analytics.log(.levelFailed(id: levelConfig.id, reason: reason,
                                   coveragePercent: Int(coverage * 100)))
        lineNode.triggerFail { [weak self] in
            guard let self, let view = self.view else { return }
            let scene = GameOverScene(reason: reason,
                                      roundScore: roundScore,
                                      levelConfig: self.levelConfig,
                                      theme: self.theme,
                                      size: self.size)
            view.presentScene(scene, transition: .fade(withDuration: 0.3))
        }
    }

    // MARK: - Win
    private func triggerWin(coverage: Float) {
        stateMachine.transition(to: .levelComplete)
        spawnTimer = 0
        Haptics.win()

        let stars = starsEarned(coverage: coverage)
        let roundScore = makeRoundScore(stars: stars)
        PlayerProgress.shared.recordCompletion(levelId: levelConfig.id,
                                               stars: stars,
                                               score: roundScore.total)
        GameCenter.submit(score: roundScore.total)
        GameCenter.reportCompletion(levelsCleared: PlayerProgress.shared.completedLevelCount,
                                    timeRemaining: timeRemaining)
        Analytics.log(.levelCleared(id: levelConfig.id, score: roundScore.total, stars: stars,
                                    secondsRemaining: Int(max(0, timeRemaining))))

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
        obstacleNodes.filter { !$0.obstacleType.severs }.count
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

        guard lethalObstacleCount < levelConfig.maxObstacles else { return }

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
        title.position = CGPoint(x: 0, y: 60)
        overlay.addChild(title)

        overlay.addChild(ButtonNode(title: "Resume", theme: theme, name: "resume_button",
                                    position: CGPoint(x: 0, y: -10)))
        overlay.addChild(ButtonNode(title: "Level Select", theme: theme, name: "levels_button",
                                    position: CGPoint(x: 0, y: -80), isPrimary: false))

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
        case "levels_button":
            let scene = LevelSelectScene(theme: theme, size: size)
            view?.presentScene(scene, transition: .fade(withDuration: 0.3))
        default:
            break
        }
    }
}
