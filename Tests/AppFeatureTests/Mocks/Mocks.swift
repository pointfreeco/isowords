import ClientModels
import ComposableArchitecture
import Foundation
import Overture
import SettingsFeature
import SharedModels

@testable import AppFeature
@testable import ComposableGameCenter

extension Game.State {
  static let mock = Self(
    cubes: .mock,
    gameContext: .solo,
    gameCurrentTime: .mock,
    gameMode: .unlimited,
    gameStartTime: .mock
  )
}
