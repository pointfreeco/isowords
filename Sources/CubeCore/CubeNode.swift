import Combine
import ComposableArchitecture
import Gen
import SceneKit
import SharedModels
import SwiftUI

public class CubeNode: SCNNode {
  public struct ViewState: Equatable {
    public var cubeShakeStartedAt: Date?
    public var index: LatticePoint
    public var isCriticallySelected: Bool
    public var isInPlay: Bool
    public var left: CubeFaceNode.ViewState
    public var right: CubeFaceNode.ViewState
    public var top: CubeFaceNode.ViewState

    public init(
      cubeShakeStartedAt: Date?,
      index: LatticePoint,
      isCriticallySelected: Bool,
      isInPlay: Bool,
      left: CubeFaceNode.ViewState,
      right: CubeFaceNode.ViewState,
      top: CubeFaceNode.ViewState
    ) {
      self.cubeShakeStartedAt = cubeShakeStartedAt
      self.index = index
      self.isCriticallySelected = isCriticallySelected
      self.isInPlay = isInPlay
      self.left = left
      self.right = right
      self.top = top
    }

    public subscript(face: CubeFace.Side) -> CubeFaceNode.ViewState {
      get {
        switch face {
        case .top:
          return self.top
        case .left:
          return self.left
        case .right:
          return self.right
        }
      }
      set {
        switch face {
        case .top:
          self.top = newValue
        case .left:
          self.left = newValue
        case .right:
          self.right = newValue
        }
      }
    }
  }

  public let index: LatticePoint

  private var leftPlaneNode: CubeFaceNode
  private var rightPlaneNode: CubeFaceNode
  private var topPlaneNode: CubeFaceNode
  private lazy var shakeAnimationActionKey = "shake animation: \(ObjectIdentifier(self))"
  private lazy var removeAnimationActionKey = "remove animation: \(ObjectIdentifier(self))"
  private var cancellables: Set<AnyCancellable> = []

  public init(
    letterGeometry: SCNGeometry,
    viewStatePublisher: StorePublisher<ViewState>
  ) {
    let viewState = viewStatePublisher.currentValue

    self.index = viewState.index
    self.leftPlaneNode = CubeFaceNode(
      letterGeometry: letterGeometry,
      viewState: viewStatePublisher.left
    )
    self.rightPlaneNode = CubeFaceNode(
      letterGeometry: letterGeometry,
      viewState: viewStatePublisher.right
    )
    self.topPlaneNode = CubeFaceNode(
      letterGeometry: letterGeometry,
      viewState: viewStatePublisher.top
    )

    super.init()

    self.isHidden = !viewState.isInPlay
    self.name =
      "xIndex: \(viewState.index.x), yIndex: \(viewState.index.y), zIndex: \(viewState.index.z)"

    for side in CubeFace.Side.allCases {
      switch side {
      case .top:
        self.addChildNode(self.topPlaneNode)
      case .left:
        self.addChildNode(self.leftPlaneNode)
      case .right:
        self.addChildNode(self.rightPlaneNode)
      }
    }

    viewStatePublisher
      .prefix(while: \.isInPlay)
      .map { ($0.isCriticallySelected, $0.index, $0.cubeShakeStartedAt) }
      .removeDuplicates(by: ==)
      .sink { [weak self] isCriticallySelected, index, cubeShakeStartedAt in
        self?.updateAnimation(
          cubeShakeStartedAt: cubeShakeStartedAt,
          isCriticallySelected: isCriticallySelected,
          index: index
        )
      }
      .store(in: &self.cancellables)

    viewStatePublisher.isInPlay
      .dropFirst()
      .sink { [weak self] isInPlay in
        guard let self = self else { return }

        self.removeAction(forKey: self.removeAnimationActionKey)
        if !isInPlay {
          self.isHidden = false

          let action = SCNAction.sequence([
            .wait(duration: Double(removeCubeDelay(index: self.index)) / 1000),
            .scale(to: 0.4, duration: 0.1),
            .scale(to: 0, duration: 0.1),
          ])
          action.timingMode = .easeOut
          self.runAction(action, forKey: self.removeAnimationActionKey) {
            self.isHidden = true
          }
        } else {
          self.isHidden = false
          self.scale = .init(0, 0, 0)
          let action = SCNAction.sequence([
            .scale(to: 0.4, duration: 0.1),
            .scale(to: 0.3333, duration: 0.1),
          ])
          action.timingMode = .easeOut
          self.runAction(action, forKey: self.removeAnimationActionKey)
        }
      }
      .store(in: &self.cancellables)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func updateAnimation(
    cubeShakeStartedAt: Date?,
    isCriticallySelected: Bool,
    index: LatticePoint
  ) {
    self.position = SCNVector3(
      CGFloat(index.x.rawValue - 1) / 3,
      CGFloat(index.y.rawValue - 1) / 3,
      CGFloat(index.z.rawValue - 1) / 3
    )

    let maxMovement: CGFloat = 0.015
    let duration: TimeInterval = 0.3
    let waitTime = 2 - (duration * 2)
    let numShakes = 10
    let shakeDuration: TimeInterval = duration / TimeInterval(numShakes)

    guard isCriticallySelected, let cubeShakeStartedAt = cubeShakeStartedAt else {
      self.removeAction(forKey: self.shakeAnimationActionKey)
      DispatchQueue.main.asyncAfter(deadline: .now() + shakeDuration) {
        self.position = SCNVector3(
          CGFloat(index.x.rawValue - 1) / 3,
          CGFloat(index.y.rawValue - 1) / 3,
          CGFloat(index.z.rawValue - 1) / 3
        )
      }
      return
    }

    let actions = (1...numShakes).flatMap { _ -> [SCNAction] in
      let action = SCNAction.moveBy(
        x: CGFloat.random(in: -maxMovement...maxMovement),
        y: CGFloat.random(in: -maxMovement...maxMovement),
        z: CGFloat.random(in: -maxMovement...maxMovement),
        duration: TimeInterval(shakeDuration)
      )
      return [action, action.reversed()]
    }

    let interval = Date().timeIntervalSince(cubeShakeStartedAt)
    let initialWaitTime =
      interval < 0.2
      ? 0
      : 2 - Date().timeIntervalSince(cubeShakeStartedAt).truncatingRemainder(dividingBy: 2)

    self.runAction(
      .sequence(
        [
          .wait(duration: initialWaitTime),
          .repeatForever(.sequence(actions + [.wait(duration: waitTime)])),
        ]
      ),
      forKey: self.shakeAnimationActionKey
    )
  }
}

public func removeCubeDelay(index: LatticePoint) -> Int {
  let seed = UInt64(index.x.rawValue * 3 * 3 * 3 + index.y.rawValue * 3 * 3 + index.z.rawValue)
  var rng = Xoshiro(seed: seed)
  return Int.random(in: 0..<300, using: &rng)
}
