import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import Foundation
import SharedModels
import Tagged

extension Game.State {
  public var displayTitle: String {
    switch self.gameContext {
    case .dailyChallenge:
      return "Daily challenge"
    case .shared, .solo:
      return "Solo"
    case let .turnBased(context):
      return context.otherPlayer
        .flatMap { $0.displayName.isEmpty ? nil : "vs \($0.displayName)" }
        ?? "Multiplayer"
    }
  }

  public var currentScore: Int {
    self.moves.reduce(into: 0) { $0 += $1.score }
  }

  public var isGameOver: Bool {
    self.destination.is(\.some.gameOver)
  }

  public var isResumable: Bool {
    self.gameMode == .unlimited && !self.isGameOver
  }

  public var isSavable: Bool {
    self.isResumable && !self.gameContext.is(\.turnBased)
  }

  public var playedWords: [PlayedWord] {
    //return []
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

  public var selectedWordScore: Int {
    score(self.selectedWordString)
  }

  public var selectedWordString: String {
    self.cubes.string(from: self.selectedWord)
  }

  public var selectedWordHasAlreadyBeenPlayed: Bool {
    self.moves.contains {
      $0.type.playedWord.map { self.cubes.string(from: $0) } == self.selectedWordString
    }
  }

  mutating func tryToRemoveCube(at index: LatticePoint) -> EffectOf<Game> {
    guard self.canRemoveCube else { return .none }

    // Don't show menu for timed games.
    guard self.gameMode != .timed
    else { return .send(.confirmRemoveCube(index)) }

    let isTurnEndingRemoval: Bool
    if let turnBasedMatch = self.gameContext.turnBased,
      let move = self.moves.last,
      case .removedCube = move.type,
      move.playerIndex == turnBasedMatch.localPlayerIndex
    {
      isTurnEndingRemoval = true
    } else {
      isTurnEndingRemoval = false
    }

    self.destination = .bottomMenu(
      .removeCube(index: index, state: self, isTurnEndingRemoval: isTurnEndingRemoval)
    )
    return .none
  }

  mutating func removeCube(at index: LatticePoint, playedAt: Date) {
    let move = Move(
      playedAt: playedAt,
      playerIndex: self.gameContext.turnBased?.localPlayerIndex,
      reactions: nil,
      score: 0,
      type: .removedCube(index)
    )

    let result = verify(
      move: move,
      on: &self.cubes,
      isValidWord: { _ in false },
      previousMoves: self.moves
    )

    guard result != nil
    else { return }

    self.moves.append(move)
    self.selectedWord = []
  }

  var canRemoveCube: Bool {
    guard let turnBasedMatch = self.gameContext.turnBased else { return true }
    guard turnBasedMatch.currentParticipantIsLocalPlayer else { return false }
    guard let lastMove = self.moves.last else { return true }
    guard
      !lastMove.type.is(\.removedCube),
      lastMove.playerIndex != turnBasedMatch.localPlayerIndex
    else {
      return true
    }
    return lastMove.playerIndex != turnBasedMatch.localPlayerIndex
  }

  public var isYourTurn: Bool {
    guard let turnBasedMatch = self.gameContext.turnBased else { return true }
    guard turnBasedMatch.match.status == .open else { return false }
    guard turnBasedMatch.currentParticipantIsLocalPlayer else { return false }
    guard let lastMove = self.moves.last else { return true }
    guard lastMove.playerIndex == turnBasedMatch.localPlayerIndex else { return true }
    guard lastMove.type.is(\.playedWord) else { return true }
    return false
  }

  public var turnBasedScores: [Move.PlayerIndex: Int] {
    Dictionary(
      grouping: self.moves
        .compactMap { move in move.playerIndex.map { (playerIndex: $0, score: move.score) } },
      by: \.playerIndex
    )
    .mapValues { $0.reduce(into: 0) { $0 += $1.score } }
  }

  public init(
    gameCurrentTime: Date,
    localPlayer: LocalPlayer,
    turnBasedMatch: TurnBasedMatch,
    turnBasedMatchData: TurnBasedMatchData
  ) {
    self.init(
      cubes: Puzzle(archivableCubes: turnBasedMatchData.cubes, moves: turnBasedMatchData.moves),
      gameContext: .turnBased(
        .init(
          localPlayer: localPlayer,
          match: turnBasedMatch,
          metadata: turnBasedMatchData.metadata
        )
      ),
      gameCurrentTime: gameCurrentTime,
      gameMode: turnBasedMatchData.gameMode,
      gameStartTime: turnBasedMatch.creationDate,
      language: turnBasedMatchData.language,
      moves: turnBasedMatchData.moves
    )
  }
}
