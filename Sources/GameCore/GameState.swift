import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import Foundation
import SharedModels
import Tagged

extension Game.State {
  public var displayTitle: String {
    switch gameContext {
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
    moves.reduce(into: 0) { $0 += $1.score }
  }

  public var isGameOver: Bool {
    destination.is(\.some.gameOver)
  }

  var isOutOfTimeOrCubes: Bool {
    let timesUp = gameMode == .timed && secondsPlayed >= gameMode.seconds
    let allCubesRemoved = cubes.allSatisfy {
      $0.allSatisfy {
        $0.allSatisfy { !$0.isInPlay }
      }
    }
    return timesUp || allCubesRemoved
  }

  public var isResumable: Bool {
    gameMode == .unlimited && !isGameOver
  }

  public var isSavable: Bool {
    isResumable && !gameContext.is(\.turnBased)
  }

  public var playedWords: [PlayedWord] {
    moves
      .reduce(into: [PlayedWord]()) {
        guard let word = $1.type.playedWord else { return }
        $0.append(
          .init(
            isYourWord: $1.playerIndex == gameContext.turnBased?.localPlayerIndex,
            reactions: $1.reactions,
            score: $1.score,
            word: cubes.string(from: word)
          )
        )
      }
  }

  public var selectedWordScore: Int {
    score(selectedWordString)
  }

  public var selectedWordString: String {
    cubes.string(from: selectedWord)
  }

  public var selectedWordHasAlreadyBeenPlayed: Bool {
    moves.contains {
      $0.type.playedWord.map { cubes.string(from: $0) } == selectedWordString
    }
  }

  mutating func tryToRemoveCube(at index: LatticePoint) -> Bool {
    guard canRemoveCube else { return false }

    // Don't show menu for timed games.
    guard gameMode != .timed
    else { return true }

    let isTurnEndingRemoval: Bool
    if let turnBasedMatch = gameContext.turnBased,
      let move = moves.last,
      case .removedCube = move.type,
      move.playerIndex == turnBasedMatch.localPlayerIndex
    {
      isTurnEndingRemoval = true
    } else {
      isTurnEndingRemoval = false
    }

    destination = .bottomMenu(
      .removeCube(index: index, state: self, isTurnEndingRemoval: isTurnEndingRemoval)
    )
    return false
  }

  mutating func removeCube(at index: LatticePoint, playedAt: Date) {
    let move = Move(
      playedAt: playedAt,
      playerIndex: gameContext.turnBased?.localPlayerIndex,
      reactions: nil,
      score: 0,
      type: .removedCube(index)
    )

    let result = verify(
      move: move,
      on: &cubes,
      isValidWord: { _ in false },
      previousMoves: moves
    )

    guard result != nil
    else { return }

    moves.append(move)
    selectedWord = []
  }

  var canRemoveCube: Bool {
    guard let turnBasedMatch = gameContext.turnBased else { return true }
    guard turnBasedMatch.currentParticipantIsLocalPlayer else { return false }
    guard let lastMove = moves.last else { return true }
    guard
      !lastMove.type.is(\.removedCube),
      lastMove.playerIndex != turnBasedMatch.localPlayerIndex
    else {
      return true
    }
    return lastMove.playerIndex != turnBasedMatch.localPlayerIndex
  }

  public var isYourTurn: Bool {
    guard let turnBasedMatch = gameContext.turnBased else { return true }
    guard turnBasedMatch.match.status == .open else { return false }
    guard turnBasedMatch.currentParticipantIsLocalPlayer else { return false }
    guard let lastMove = moves.last else { return true }
    guard lastMove.playerIndex == turnBasedMatch.localPlayerIndex else { return true }
    guard lastMove.type.is(\.playedWord) else { return true }
    return false
  }

  public var turnBasedScores: [Move.PlayerIndex: Int] {
    Dictionary(
      grouping: moves
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
