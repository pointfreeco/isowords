import ClientModels
import GameKit
import SharedModels

public struct CompletedMatch: Equatable {
  public let isTurnBased: Bool
  public let theirName: String
  public let theirOutcome: GKTurnBasedMatch.Outcome
  public let theirScore: Int
  public let theirWords: [PlayedWord]
  public let yourName: String
  public let yourOutcome: GKTurnBasedMatch.Outcome

  public init(
    isTurnBased: Bool,
    theirName: String,
    theirOutcome: GKTurnBasedMatch.Outcome,
    theirScore: Int,
    theirWords: [PlayedWord],
    yourName: String,
    yourOutcome: GKTurnBasedMatch.Outcome
  ) {
    self.isTurnBased = isTurnBased
    self.theirName = theirName
    self.theirOutcome = theirOutcome
    self.theirScore = theirScore
    self.theirWords = theirWords
    self.yourName = yourName
    self.yourOutcome = yourOutcome
  }
}

extension CompletedMatch {
  public init?(
    completedGame: CompletedGame,
    turnBasedContext: TurnBasedContext
  ) {
    guard let otherPlayerIndex = turnBasedContext.otherPlayerIndex
    else { return nil }

    let theirWords = completedGame.cubes.words(
      forMoves: .init(completedGame.moves.filter { $0.playerIndex == otherPlayerIndex })
    )
    let theirScore = theirWords.reduce(into: 0) { $0 += $1.score }
    let theirCurrentOutcome = turnBasedContext.match.participants[otherPlayerIndex.rawValue]
      .matchOutcome
    let yourWords = completedGame.cubes.words(
      forMoves: .init(
        completedGame.moves.filter { $0.playerIndex == turnBasedContext.localPlayerIndex })
    )
    let yourScore = yourWords.reduce(into: 0) { $0 += $1.score }
    guard let localPlayerIndex = turnBasedContext.localPlayerIndex
    else { return nil }
    let yourCurrentOutcome = turnBasedContext.match.participants[localPlayerIndex.rawValue]
      .matchOutcome
    let theirOutcome: GKTurnBasedMatch.Outcome
    let yourOutcome: GKTurnBasedMatch.Outcome
    switch (theirCurrentOutcome, yourCurrentOutcome) {
    case (.none, .none):
      (theirOutcome, yourOutcome) =
        theirScore == yourScore
        ? (.tied, .tied)
        : theirScore > yourScore
          ? (.won, .lost)
          : (.lost, .won)
    case (.none, .quit):
      (theirOutcome, yourOutcome) = (.won, .quit)
    case (.quit, .none):
      (theirOutcome, yourOutcome) = (.quit, .won)
    default:
      (theirOutcome, yourOutcome) = (theirCurrentOutcome, yourCurrentOutcome)
    }
    self.init(
      isTurnBased: true,
      theirName: turnBasedContext.otherPlayer?.displayName ?? "Your opponent",
      theirOutcome: theirOutcome,
      theirScore: theirScore,
      theirWords: theirWords,
      yourName: turnBasedContext.localPlayer.displayName,
      yourOutcome: yourOutcome
    )
  }

  public init(
    completedGame: CompletedGame,
    sharedGameResponse: SharedGameResponse
  ) {
    let yourWords = completedGame.words()
    let yourScore = yourWords.reduce(into: 0) { $0 += $1.score }

    let theirWords = sharedGameResponse.puzzle.words(forMoves: sharedGameResponse.moves)
    let theirScore = theirWords.reduce(into: 0) { $0 += $1.score }
    let yourOutcome: GKTurnBasedMatch.Outcome
    let theirOutcome: GKTurnBasedMatch.Outcome
    (yourOutcome, theirOutcome) =
      yourScore == theirScore
      ? (.tied, .tied)
      : yourScore > theirScore
        ? (.won, .lost)
        : (.lost, .won)
    self.init(
      isTurnBased: false,
      theirName: "Your opponent",
      theirOutcome: theirOutcome,
      theirScore: theirScore,
      theirWords: theirWords,
      yourName: "You",
      yourOutcome: yourOutcome
    )
  }
}
