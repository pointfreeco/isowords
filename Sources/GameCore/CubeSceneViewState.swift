import ClientModels
import Combine
import ComposableArchitecture
import ComposableStoreKit
import CoreMotion
import CubeCore
import Foundation
import GameOverFeature
import Overture
import SceneKit
import SharedModels
import Styleguide
import SwiftUI
import SwiftUIHelpers

extension CubeSceneView.ViewState {
  public init(
    game: GameState,
    nub: CubeSceneView.ViewState.NubState?,
    settings: Settings
  ) {
    self.init(
      cubes: game.cubes.enumerated().map { x, cubes in
        cubes.enumerated().map { y, cubes in
          cubes.enumerated().map { z, _ in
            CubeNode.ViewState(
              viewState: game,
              index: .init(x: x, y: y, z: z)
            )
          }
        }
      },
      isOnLowPowerMode: game.isOnLowPowerMode,
      nub: nub,
      playedWords: game.playedWords,
      selectedFaceCount: game.selectedWord.count,
      selectedWordIsValid: game.selectedWordIsValid,
      selectedWordString: game.selectedWordString,
      settings: settings
    )
  }
}

extension CubeSceneView.ViewAction {
  public static func to(gameAction action: Self) -> GameAction {
    switch action {
    case let .doubleTap(index: index):
      return .doubleTap(index: index)
    case let .pan(state, data):
      return .pan(state, data)
    case let .tap(state, indexedCubeFace):
      return .tap(state, indexedCubeFace)
    }
  }
}

extension CubeNode.ViewState {
  init(viewState: GameState, index: LatticePoint) {
    let index = index
    let isInPlay = viewState.cubes[index].isInPlay

    let leftIndex = IndexedCubeFace(index: index, side: .left)
    let left = CubeFaceNode.ViewState(
      cubeFace: viewState.cubes[index].left,
      status: viewState.selectedWord.contains(leftIndex)
        ? .selected
        : viewState.selectedWord.last.map {
          $0.isTouching(leftIndex) && viewState.cubes.isPlayable(side: .left, index: index)
            ? .selectable
            : .deselected
        }
          ?? .deselected
    )

    let rightIndex = IndexedCubeFace(index: index, side: .right)
    let right = CubeFaceNode.ViewState(
      cubeFace: viewState.cubes[index].right,
      status: viewState.selectedWord.contains(rightIndex)
        ? .selected
        : viewState.selectedWord.last.map {
          $0.isTouching(rightIndex) && viewState.cubes.isPlayable(side: .right, index: index)
            ? .selectable
            : .deselected
        }
          ?? .deselected
    )

    let topIndex = IndexedCubeFace(index: index, side: .top)
    let top = CubeFaceNode.ViewState(
      cubeFace: viewState.cubes[index].top,
      status: viewState.selectedWord.contains(topIndex)
        ? .selected
        : viewState.selectedWord.last.map {
          $0.isTouching(topIndex) && viewState.cubes.isPlayable(side: .top, index: index)
            ? .selectable
            : .deselected
        }
          ?? .deselected
    )

    let isCriticallySelected =
      viewState.selectedWordIsValid
      && (left.status == .selected && left.cubeFace.useCount == 2
        || right.status == .selected && right.cubeFace.useCount == 2
        || top.status == .selected && top.cubeFace.useCount == 2)

    self = .init(
      cubeShakeStartedAt: viewState.cubeStartedShakingAt,
      index: index,
      isCriticallySelected: isCriticallySelected,
      isInPlay: isInPlay,
      left: left,
      right: right,
      top: top
    )
  }
}
