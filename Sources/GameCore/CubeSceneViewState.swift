import CubeCore
import SharedModels

extension CubeSceneView.ViewState {
  public init(
    game: Game.State,
    nub: CubeSceneView.ViewState.NubState? = nil
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
      enableGyroMotion: game.enableGyroMotion,
      isOnLowPowerMode: game.isOnLowPowerMode,
      nub: nub,
      playedWords: game.playedWords,
      selectedFaceCount: game.selectedWord.count,
      selectedWordIsValid: game.selectedWordIsValid,
      selectedWordString: game.selectedWordString
    )
  }
}

extension CubeSceneView.ViewAction {
  public static func to(gameAction action: Self) -> Game.Action {
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
  init(viewState: Game.State, index: LatticePoint) {
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
