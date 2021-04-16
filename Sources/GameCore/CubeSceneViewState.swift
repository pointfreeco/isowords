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
    let cubes = game.replay?.cubes ?? game.cubes
    self.init(
      cubes: cubes.enumerated().map { x, xCubes in
        xCubes.enumerated().map { y, yCubes in
          yCubes.enumerated().map { z, _ in
            CubeNode.ViewState(
              cubes: cubes,
              cubeStartedShakingAt: game.cubeStartedShakingAt, // TODO: replay state?
              index: .init(x: x, y: y, z: z),
              selectedWord: game.replay?.selectedWord ?? game.selectedWord,
              selectedWordIsValid: game.replay?.selectedWordIsValid ?? game.selectedWordIsValid
            )
          }
        }
      },
      isOnLowPowerMode: game.isOnLowPowerMode,
      nub: nub ?? game.replay?.nub,
      playedWordsCount: game.playedWords.count,
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
  init(
    cubes: Puzzle,
    cubeStartedShakingAt: Date?,
    index: LatticePoint,
    selectedWord: [IndexedCubeFace],
    selectedWordIsValid: Bool
  ) {
    let isInPlay = cubes[index].isInPlay

    let leftIndex = IndexedCubeFace(index: index, side: .left)
    let left = CubeFaceNode.ViewState(
      cubeFace: cubes[index].left,
      status: selectedWord.contains(leftIndex)
        ? .selected
        : selectedWord.last.map {
          $0.isTouching(leftIndex) && cubes.isPlayable(side: .left, index: index)
            ? .selectable
            : .deselected
        }
          ?? .deselected
    )

    let rightIndex = IndexedCubeFace(index: index, side: .right)
    let right = CubeFaceNode.ViewState(
      cubeFace: cubes[index].right,
      status: selectedWord.contains(rightIndex)
        ? .selected
        : selectedWord.last.map {
          $0.isTouching(rightIndex) && cubes.isPlayable(side: .right, index: index)
            ? .selectable
            : .deselected
        }
          ?? .deselected
    )

    let topIndex = IndexedCubeFace(index: index, side: .top)
    let top = CubeFaceNode.ViewState(
      cubeFace: cubes[index].top,
      status: selectedWord.contains(topIndex)
        ? .selected
        : selectedWord.last.map {
          $0.isTouching(topIndex) && cubes.isPlayable(side: .top, index: index)
            ? .selectable
            : .deselected
        }
          ?? .deselected
    )

    let isCriticallySelected =
      selectedWordIsValid
      && (left.status == .selected && left.cubeFace.useCount == 2
        || right.status == .selected && right.cubeFace.useCount == 2
        || top.status == .selected && top.cubeFace.useCount == 2)

    self = .init(
      cubeShakeStartedAt: cubeStartedShakingAt,
      index: index,
      isCriticallySelected: isCriticallySelected,
      isInPlay: isInPlay,
      left: left,
      right: right,
      top: top
    )
  }
}
