import ClientModels
import ComposableArchitecture
import Foundation
import GameFeature
import Overture
import SettingsFeature
import SharedModels

@testable import AppFeature
@testable import ComposableGameCenter

extension GameFeature.State {
  static let mock = Self(
    game: .mock,
    settings: .everythingOff
  )
}

extension Game.State {
  static let mock = Self(
    cubes: .mock,
    gameContext: .solo,
    gameCurrentTime: .mock,
    gameMode: .unlimited,
    gameStartTime: .mock
  )
}
