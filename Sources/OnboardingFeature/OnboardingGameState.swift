import Foundation
import GameCore
import PuzzleGen
import SharedModels

extension Game.State {
  public static let onboarding = Self(
    inProgressGame: .init(
      cubes: .onboarding,
      gameContext: .solo,
      gameMode: .unlimited,
      gameStartTime: Date(),
      language: .en,
      moves: [],
      secondsPlayed: 0
    )
  )
}

extension Puzzle {
  static var onboarding: Self {
    var cubes = randomCubes(for: isowordsLetter).run()
    cubes.1.2.2.left.letter = "G"
    cubes.2.2.2.left.letter = "A"
    cubes.2.2.2.right.letter = "M"
    cubes.2.2.1.right.letter = "E"

    cubes.1.2.2.top.letter = "C"
    cubes.1.2.1.top.letter = "U"
    cubes.2.2.2.top.letter = "B"
    cubes.2.2.1.right.letter = "E"
    cubes.2.2.1.top.letter = "S"

    cubes.1.1.2.left.letter = "R"
    cubes.2.1.2.left.letter = "E"
    cubes.2.2.2.right.letter = "M"
    cubes.2.1.2.right.letter = "O"
    cubes.2.1.1.right.letter = "V"
    cubes.2.2.1.right.letter = "E"

    cubes.1.2.1.right.letter = "A"
    cubes.2.1.1.top.letter = "M"
    cubes.2.2.0.left.letter = "S"

    cubes.0.2.0.top.letter = "P"
    cubes.0.2.1.top.letter = "I"
    cubes.0.2.2.top.letter = "L"
    cubes.0.2.2.left.letter = "L"
    cubes.0.1.2.left.letter = "O"
    cubes.2.0.2.right.letter = "W"

    cubes.0.0.2.left.letter = "W"
    cubes.1.0.2.left.letter = "O"
    cubes.2.0.2.left.letter = "R"
    cubes.2.0.2.right.letter = "D"
    cubes.2.0.1.right.letter = "S"

    cubes.0.2.0.top.letter = "P"
    cubes.1.2.0.top.letter = "U"
    cubes.2.2.0.top.letter = "Z"
    cubes.2.2.0.right.letter = "Z"
    cubes.2.1.0.right.letter = "L"
    cubes.2.0.0.right.letter = "E"

    return cubes
  }
}
