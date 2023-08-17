import ComposableArchitecture
@_exported import GameCore
import SettingsFeature
import TcaHelpers

public struct GameFeature: Reducer {
  public struct State: Equatable {
    public var game: Game.State?

    public init(
      game: Game.State?
    ) {
      self.game = game
    }
  }

  public enum Action: Equatable {
    case game(Game.Action)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    IntegratedGame(
      state: OptionalPath(\.game),
      action: /Action.game
    )
  }
}
