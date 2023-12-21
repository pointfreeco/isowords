import ClientModels
import Combine
import ComposableArchitecture
import CoreMotion
import SceneKit
import SharedModels
import Styleguide
import SwiftUI

public class CubeSceneView: SCNView, UIGestureRecognizerDelegate {
  public struct ViewState: Equatable {
    public typealias ViewPuzzle = Three<Three<Three<CubeNode.ViewState>>>

    public var cubes: ViewPuzzle
    public var enableGyroMotion: Bool
    public var isOnLowPowerMode: Bool
    public var nub: NubState?
    public var playedWords: [PlayedWord]
    public var selectedFaceCount: Int
    public var selectedWordIsValid: Bool
    public var selectedWordString: String

    public init(
      cubes: ViewPuzzle,
      enableGyroMotion: Bool,
      isOnLowPowerMode: Bool,
      nub: NubState?,
      playedWords: [PlayedWord],
      selectedFaceCount: Int,
      selectedWordIsValid: Bool,
      selectedWordString: String
    ) {
      self.cubes = cubes
      self.enableGyroMotion = enableGyroMotion
      self.isOnLowPowerMode = isOnLowPowerMode
      self.nub = nub
      self.playedWords = playedWords
      self.selectedFaceCount = selectedFaceCount
      self.selectedWordIsValid = selectedWordIsValid
      self.selectedWordString = selectedWordString
    }

    public struct NubState: Equatable {
      public var duration: TimeInterval
      public var location: Location
      public var isPressed: Bool

      public init(
        duration: TimeInterval = 0,
        location: Location = .offScreenRight,
        isPressed: Bool = false
      ) {
        self.duration = duration
        self.location = location
        self.isPressed = isPressed
      }

      public enum Location: Equatable {
        case face(IndexedCubeFace)
        case offScreenBottom
        case offScreenRight
        case submitButton
      }
    }
  }

  public enum ViewAction {
    case doubleTap(index: LatticePoint)
    case pan(UIGestureRecognizer.State, PanData?)
    case tap(UIGestureRecognizer.State, IndexedCubeFace?)
  }

  private static let defaultCameraPosition = SCNVector3(2, 1.85, 2)

  private let cameraNode = SCNNode()
  private var cancellables: Set<AnyCancellable> = []
  private let gameCubeNode = SCNNode()
  private let light = SCNLight()
  private var motionManager: CMMotionManager?
  private var startingAttitude: Attitude?
  private let viewStore: ViewStore<ViewState, ViewAction>
  private var worldScale: Float = 1.0

  var enableCubeShadow = true {
    didSet { self.update() }
  }
  var showSceneStatistics = false {
    didSet { self.update() }
  }

  public init(
    size: CGSize,
    viewStore: ViewStore<ViewState, ViewAction>
  ) {
    self.viewStore = viewStore

    super.init(frame: .zero, options: nil)

    self.scene = SCNScene()
    self.scene?.background.contents = UIColor.clear
    self.backgroundColor = .clear

    let camera = SCNCamera()

    self.pointOfView = self.cameraNode

    self.cameraNode.camera = camera
    self.cameraNode.name = "camera"
    self.cameraNode.camera?.usesOrthographicProjection = true
    self.cameraNode.position = Self.defaultCameraPosition
    self.scene?.rootNode.addChildNode(self.cameraNode)

    self.gameCubeNode.name = "gameCube"
    worldScale = self.worldScale(for: size)
    gameCubeNode.scale = .init(worldScale, worldScale, worldScale)
    self.scene?.rootNode.addChildNode(self.gameCubeNode)

    self.viewStore.publisher.cubes
      .sink { cubes in
        SCNTransaction.begin()
        SCNTransaction.commit()
      }
      .store(in: &self.cancellables)

    self.viewStore.publisher.cubes
      .removeDuplicates(by: { $0.letters == $1.letters })
      .sink { [weak self] cubes in
        guard let self = self else { return }

        let letterGeometry = LetterGeometry(width: 1, height: 1)
        letterGeometry.loadShaders(puzzle: cubes, worldScale: self.worldScale)

        self.gameCubeNode.childNodes.forEach { $0.removeFromParentNode() }


        LatticePoint.cubeIndices.forEach { index in
          let cube = CubeNode(
            letterGeometry: letterGeometry,
            initialState: self.viewStore.cubes[index],
            cube: self.viewStore.publisher.cubes[index]
          )
          cube.scale = SCNVector3(x: 1 / 3, y: 1 / 3, z: 1 / 3)
          self.gameCubeNode.addChildNode(cube)
        }

        // NB: "Warm" the scene with selected/selectable faces to avoid a hitch when selecting the
        //     first letter
        [CubeFaceNode.ViewState.Status.selected, .selectable].forEach { status in
          let warmer = CubeFaceNode(
            letterGeometry: letterGeometry,
            initialState: .init(
              cubeFace: .init(letter: "A", side: .top),
              letterIsHidden: true,
              status: status
            ),
            face: Store<CubeFaceNode.ViewState, Never>(
              initialState: .init(
                cubeFace: .init(letter: "A", side: .top),
                letterIsHidden: true,
                status: status
              )
            ) {
            }.publisher
          )
          warmer.position = .init(-1, -1, -1)
          warmer.scale = .init(0.001, 0.001, 0.001)
          self.gameCubeNode.addChildNode(warmer)
          DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            warmer.removeFromParentNode()
          }
        }
      }
      .store(in: &self.cancellables)

    let cameraLookAtOriginConstraint = SCNLookAtConstraint(target: self.gameCubeNode)
    cameraLookAtOriginConstraint.isGimbalLockEnabled = true
    self.cameraNode.constraints = [cameraLookAtOriginConstraint]

    light.automaticallyAdjustsShadowProjection = true
    light.shadowSampleCount = 8
    light.shadowRadius = 5
    light.type = .directional
    light.category = .shadowSurface
    let lightNode = SCNNode()
    lightNode.name = "light"
    lightNode.light = light
    lightNode.position = SCNVector3(1.1, 1.65, 1)
    lightNode.constraints = [SCNLookAtConstraint(target: self.gameCubeNode)]
    self.scene?.rootNode.addChildNode(lightNode)

    let ambientLight = SCNLight()
    ambientLight.name = "ambient light"
    ambientLight.type = .ambient
    ambientLight.intensity = 300
    let ambientLightNode = SCNNode()
    ambientLightNode.light = ambientLight
    self.scene?.rootNode.addChildNode(ambientLightNode)

    self.viewStore.publisher
      .map { ($0.enableGyroMotion, $0.isOnLowPowerMode) }
      .removeDuplicates(by: ==)
      .sink { [weak self] enableGyroMotion, isOnLowPowerMode in
        guard let self = self else { return }

        self.showsStatistics = self.showSceneStatistics
        light.castsShadow = self.enableCubeShadow && !isOnLowPowerMode

        if isOnLowPowerMode || !enableGyroMotion {
          self.stopMotionManager()
        } else {
          self.startMotionManager()
        }
      }
      .store(in: &self.cancellables)

    self.viewStore.publisher.playedWords
      .sink { [weak self] _ in self?.startingAttitude = nil }
      .store(in: &self.cancellables)

    let immediateTapRecognizer = UILongPressGestureRecognizer(
      target: self, action: #selector(tap(recognizer:)))
    immediateTapRecognizer.cancelsTouchesInView = false
    immediateTapRecognizer.delegate = self
    immediateTapRecognizer.minimumPressDuration = 0
    self.addGestureRecognizer(immediateTapRecognizer)

    let doubleTapRecognizer = UITapGestureRecognizer(
      target: self,
      action: #selector(doubleTap(recognizer:))
    )
    doubleTapRecognizer.delegate = self
    doubleTapRecognizer.numberOfTapsRequired = 2
    self.addGestureRecognizer(doubleTapRecognizer)

    let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(pan(recognizer:)))
    panRecognizer.delegate = self
    self.addGestureRecognizer(panRecognizer)

    let nub = NubUIView()
    nub.isHidden = true
    self.addSubview(nub)

    self.viewStore.publisher.nub
      .compactMap { $0?.isPressed }
      .removeDuplicates()
      .assign(to: \.isPressed, on: nub)
      .store(in: &self.cancellables)

    self.viewStore.publisher.nub
      .compactMap { $0?.location }
      .removeDuplicates()
      .sink { [weak self] location in
        guard let self = self else { return }

        nub.isHidden = false

        switch location {
        case .offScreenBottom:
          nub.transform = .init(
            translationX: UIScreen.main.bounds.width / 2,
            y: UIScreen.main.bounds.height + 10
          )
        case .offScreenRight:
          nub.transform = .init(
            translationX: UIScreen.main.bounds.width + 10,
            y: UIScreen.main.bounds.height / 2
          )

        case let .face(face):
          let linearIndex =
            3 * 3 * face.index.x.rawValue
            + 3 * face.index.y.rawValue
            + face.index.z.rawValue

          let faceNode = self.gameCubeNode
            .childNodes[linearIndex]
            .childNodes[face.side.rawValue]

          let rootPosition = self.scene!.rootNode.convertPosition(.init(), from: faceNode)
          let screenPosition = self.projectPoint(rootPosition)
          nub.transform = .init(
            translationX: CGFloat(screenPosition.x) - nub.bounds.midX,
            y: CGFloat(screenPosition.y) - nub.bounds.midY
          )

        case .submitButton:
          nub.transform = .init(
            translationX: self.bounds.midX - nub.bounds.midX + .random(in: -10...10),
            y: self.bounds.maxY - nub.bounds.midY - 130 + .random(in: -10...10)
          )
        }
      }
      .store(in: &self.cancellables)
  }

  // TODO: rename
  private func update() {
    self.showsStatistics = self.showSceneStatistics
    self.light.castsShadow = self.enableCubeShadow && !self.viewStore.isOnLowPowerMode
  }

  deinit {
    self.stopMotionManager()
  }

  private func worldScale(for size: CGSize) -> Float {
    let aspectRatio = Float(size.width / size.height)
    let scale = min(aspectRatio * 1.3, 0.8)
    return scale
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    guard self.bounds.size.height != 0 else { return }
    worldScale = self.worldScale(for: self.bounds.size)
    gameCubeNode.scale = .init(worldScale, worldScale, worldScale)
  }

  @objc private func doubleTap(recognizer: UIGestureRecognizer) {
    guard recognizer.state == .ended else { return }

    let location = recognizer.location(in: self)

    guard let (_, _, cubeNode) = self.nodes(location: location)
    else { return }

    self.viewStore.send(.doubleTap(index: cubeNode.index), animation: .default)
  }

  @objc private func tap(recognizer: UIGestureRecognizer) {
    guard recognizer.state != .changed
    else { return }

    let location = recognizer.location(in: self)

    self.viewStore.send(
      .tap(
        recognizer.state,
        self.nodes(location: location)
          .map { _, cubeFaceNode, cubeNode in
            IndexedCubeFace(
              index: cubeNode.index, side: cubeFaceNode.side
            )
          }
      ),
      animation: .default
    )
  }

  @objc private func pan(recognizer: UIGestureRecognizer) {
    let location = recognizer.location(in: self)

    let panData = self.nodes(location: location).map { hit, cubeFaceNode, cubeNode in
      PanData(
        normalizedPoint: .init(
          x: CGFloat(hit.localCoordinates.x),
          y: CGFloat(hit.localCoordinates.y)
        ),
        cubeFaceState: .init(
          index: cubeNode.index, side: cubeFaceNode.side
        )
      )
    }

    self.viewStore.send(.pan(recognizer.state, panData), animation: .default)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func nodes(location: CGPoint) -> (SCNHitTestResult, CubeFaceNode, CubeNode)? {
    let hits = self.hitTest(
      location,
      options: [
        .categoryBitMask: NSNumber(value: Category.cubeFace.rawValue),
        .firstFoundOnly: NSNumber(value: true),
        .searchMode: NSNumber(value: SCNHitTestSearchMode.closest.rawValue),
      ]
    )

    guard
      let hit = hits.first,
      let cubeFaceNode = hit.node as? CubeFaceNode,
      let cubeNode = cubeFaceNode.parent as? CubeNode
    else { return nil }

    return (hit, cubeFaceNode, cubeNode)
  }

  public func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    true
  }

  private func startMotionManager() {
    guard self.motionManager == nil else { return }

    self.motionManager = CMMotionManager()

    self.motionManager?
      .startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) {
        [weak self] motion, error in
        guard let self = self else { return }

        self.startingAttitude = self.startingAttitude ?? (motion?.attitude).map(Attitude.init)
        guard
          let motion = motion,
          let initialAttitude = self.startingAttitude
        else { return }

        let attitude = Attitude(motion.attitude).multiply(byInverseOf: initialAttitude)
        let perturbation = SCNVector3(
          x: max(-0.3, min(0.3, Float(attitude.yaw))),
          y: max(-0.3, min(0.3, Float(-attitude.roll))),
          z: 0
        )

        self.cameraNode.position = .init(
          self.cameraNode.position.x
            + ((Self.defaultCameraPosition.x + perturbation.x) - self.cameraNode.position.x) / 10,
          self.cameraNode.position.y
            + ((Self.defaultCameraPosition.y + perturbation.y) - self.cameraNode.position.y) / 10,
          Self.defaultCameraPosition.z
        )
      }
  }

  private func stopMotionManager() {
    self.motionManager?.stopDeviceMotionUpdates()
    self.motionManager = nil
    self.cameraNode.position = Self.defaultCameraPosition
  }
}

extension CubeSceneView.ViewState.ViewPuzzle {
  fileprivate var letters: [String] {
    self.flatMap {
      $0.flatMap {
        $0.flatMap {
          [$0.left.cubeFace.letter, $0.right.cubeFace.letter, $0.top.cubeFace.letter]
        }
      }
    }
  }
}

extension SCNVector3 {
  var length: Float {
    sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
  }
}
