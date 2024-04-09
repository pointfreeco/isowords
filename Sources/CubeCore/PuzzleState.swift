import ClientModels
import SharedModels

public struct PuzzleState: Equatable {
  public var cubes: Puzzle
  public var gameContext: ClientModels.GameContext
  public var moves: Moves
  public var nub: CubeSceneView.ViewState.NubState?
  public var selectedWord: [IndexedCubeFace]
  public var selectedWordIsValid: Bool

  public init(
    cubes: Puzzle,
    gameContext: ClientModels.GameContext,
    moves: Moves = [],
    nub: CubeSceneView.ViewState.NubState? = nil,
    selectedWord: [IndexedCubeFace] = [],
    selectedWordIsValid: Bool = false
  ) {
    self.cubes = cubes
    self.gameContext = gameContext
    self.moves = moves
    self.nub = nub
    self.selectedWord = selectedWord
    self.selectedWordIsValid = selectedWordIsValid
  }
  public var selectedWordString: String {
    self.cubes.string(from: self.selectedWord)
  }
  public var playedWords: [PlayedWord] {
    self.moves
      .reduce(into: [PlayedWord]()) {
        guard let word = $1.type.playedWord else { return }
        $0.append(
          .init(
            isYourWord: $1.playerIndex == self.gameContext.turnBased?.localPlayerIndex,
            reactions: $1.reactions,
            score: $1.score,
            word: self.cubes.string(from: word)
          )
        )
      }
  }
}
