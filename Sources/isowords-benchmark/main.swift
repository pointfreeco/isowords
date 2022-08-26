import AppFeature
import ClientModels
import GameFeature
import HomeFeature
import Benchmark

var appState = AppState(
  game: GameState(
    inProgressGame: InProgressGame(
      cubes: .mock,
      gameContext: .solo,
      gameMode: .unlimited,
      gameStartTime: .mock,
      language: .en,
      moves: [],
      secondsPlayed: 0
    )
  ),
  home: HomeState(),
  onboarding: nil
)

let appEnvironment = AppEnvironment(
  apiClient: .noop,
  applicationClient: .noop,
  audioPlayer: .noop,
  backgroundQueue: .global(),
  build: .noop,
  database: .noop,
  deviceId: .noop,
  dictionary: .everyString,
  feedbackGenerator: .noop,
  fileClient: .noop,
  gameCenter: .noop,
  lowPowerMode: .false,
  mainQueue: .main,
  mainRunLoop: .main,
  remoteNotifications: .noop,
  serverConfig: .noop,
  setUserInterfaceStyle: { _ in },
  storeKit: .noop,
  timeZone: { .autoupdatingCurrent },
  userDefaults: .noop,
  userNotifications: .noop
)

benchmark("app reducer") {
  appReducer.run(&appState, AppAction.currentGame(.settings(.task)), appEnvironment)
}

Benchmark.main()
