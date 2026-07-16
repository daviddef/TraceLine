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

        // Pose obstacles in the gaps between passes. An obstacle touching the line would
        // mean the round had already ended, so a screenshot showing that misstates the
        // rules — keep them clear of the drawn path.
        var placed: [CGPoint] = []
        for type in levelConfig.obstacleTypes.prefix(2) {
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
            if obs.position.y < playRect.minY - 40 { recycleObstacle(obs) }
        }

        spawnTimer += dt
        if !isDemoPath,
           spawnTimer >= levelConfig.spawnInterval && obstacleNodes.count < levelConfig.maxObstacles {
            spawnObstacle()
            spawnTimer = 0
        }

        guard stateMachine.phase == .drawing else { return }

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
    private func spawnObstacle() {
        guard let type = levelConfig.obstacleTypes.randomElement() else { return }
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
