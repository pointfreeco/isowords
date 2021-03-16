import ClientModels
import ComposableArchitecture
import Foundation
import GameFeature
import Overture
import SettingsFeature
import SharedModels

@testable import AppFeature
@testable import ComposableGameCenter

extension Cube: CustomDebugOutputConvertible {
  public var debugOutput: String {
    return """
      \(self.top.letter)\(self.top.useCount)|\
      \(self.left.letter)\(self.left.useCount)|\
      \(self.right.letter)\(self.right.useCount)
      """
  }
}

extension GameFeatureState {
  static let mock = Self(
    game: .mock,
    settings: .everythingOff
  )
}

extension GameState {
  static let mock = Self(
    cubes: .mock,
    gameContext: .solo,
    gameCurrentTime: .mock,
    gameMode: .unlimited,
    gameStartTime: .mock
  )
}
