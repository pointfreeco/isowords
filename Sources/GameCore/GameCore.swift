import ActiveGamesFeature
import ApiClient
import AudioPlayerClient
import BottomMenu
import Build
import CasePaths
import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import ComposableGameCenterHelpers
import ComposableStoreKit
import ComposableUserNotifications
import CubeCore
import DictionaryClient
import FeedbackGeneratorClient
import FileClient
import GameOverFeature
import Gen
import HapticsCore
import LocalDatabaseClient
import LowPowerModeClient
import Overture
import PuzzleGen
import RemoteNotificationsClient
import ServerConfigClient
import SharedModels
import SwiftUI
import UIApplicationClient
import UpgradeInterstitialFeature
import UserDefaultsClient

public struct GameState: Equatable {
  public var activeGames: ActiveGamesState
  public var alert: AlertState<GameAction.AlertAction>?
  public var bottomMenu: BottomMenuState<GameAction>?
  public var cubes: Puzzle
  public var cubeStartedShakingAt: Date?
  public var gameContext: ClientModels.GameContext
  public var gameCurrentTime: Date
  public var gameMode: GameMode
  public var gameOver: GameOverState?
  public var gameStartTime: Date
  public var isDemo: Bool
  public var isGameLoaded: Bool
  public var isOnLowPowerMode: Bool
  public var isPanning: Bool
  public var isSettingsPresented: Bool
  public var isTrayVisible: Bool
  public var language: Language
  public var moves: Moves
  public var optimisticallySelectedFace: IndexedCubeFace?
  public var secondsPlayed: Int
  public var selectedWord: [IndexedCubeFace]
  public var selectedWordIsValid: Bool
  public var upgradeInterstitial: UpgradeInterstitialState?
  public var wordSubmitButton: WordSubmitButtonState

  public init(
    activeGames: ActiveGamesState = .init(),
    alert: AlertState<GameAction.AlertAction>? = nil,
    bottomMenu: BottomMenuState<GameAction>? = nil,
    cubes: Puzzle,
    cubeStartedShakingAt: Date? = nil,
    gameContext: ClientModels.GameContext,
    gameCurrentTime: Date,
    gameMode: GameMode,
    gameOver: GameOverState? = nil,
    gameStartTime: Date,
    isDemo: Bool = false,
    isGameLoaded: Bool = false,
    isPanning: Bool = false,
    isOnLowPowerMode: Bool = false,
    isSettingsPresented: Bool = false,
    isTrayVisible: Bool = false,
    language: Language = .en,
    moves: Moves = [],
    optimisticallySelectedFace: IndexedCubeFace? = nil,
    secondsPlayed: Int = 0,
    selectedWord: [IndexedCubeFace] = [],
    selectedWordIsValid: Bool = false,
    upgradeInterstitial: UpgradeInterstitialState? = nil,
    wordSubmit: WordSubmitButtonState = .init()
  ) {
    self.activeGames = activeGames
    self.alert = alert
    self.bottomMenu = bottomMenu
    self.cubes = cubes
    self.cubeStartedShakingAt = cubeStartedShakingAt
    self.gameContext = gameContext
    self.gameCurrentTime = gameCurrentTime
    self.gameMode = gameMode
    self.gameOver = gameOver
    self.gameStartTime = gameStartTime
    self.isDemo = isDemo
    self.isGameLoaded = isGameLoaded
    self.isOnLowPowerMode = isOnLowPowerMode
    self.isPanning = isPanning
    self.isSettingsPresented = isSettingsPresented
    self.isTrayVisible = isTrayVisible
    self.language = language
    self.moves = moves
    self.optimisticallySelectedFace = optimisticallySelectedFace
    self.secondsPlayed = secondsPlayed
    self.selectedWord = selectedWord
    self.selectedWordIsValid = selectedWordIsValid
    self.upgradeInterstitial = upgradeInterstitial
    self.wordSubmitButton = wordSubmit
  }

  public var dailyChallengeId: DailyChallenge.Id? {
    guard case let .dailyChallenge(id) = self.gameContext else { return nil }
    return id
  }

  public var isNavVisible: Bool {
    !self.isDemo
  }

  public var isTrayAvailable: Bool {
    self.gameMode != .timed && !self.activeGames.isEmpty
  }

  public var turnBasedContext: TurnBasedContext? {
    get {
      guard case let .turnBased(context) = self.gameContext else { return nil }
      return context
    }
    set {
      guard let newValue = newValue else { return }
      self.gameContext = .turnBased(newValue)
    }
  }

  public var wordSubmitButtonFeature: WordSubmitButtonFeatureState {
    get {
      .init(
        isSelectedWordValid: self.selectedWordIsValid,
        isTurnBasedMatch: self.turnBasedContext != nil,
        isYourTurn: self.turnBasedContext?.currentParticipantIsLocalPlayer ?? true,
        selectedWordIsValid: self.selectedWordIsValid,
        wordSubmitButton: self.wordSubmitButton
      )
    }
    set {
      self.wordSubmitButton = newValue.wordSubmitButton
    }
  }
}

public enum GameAction: Equatable {
  case activeGames(ActiveGamesAction)
  case alert(AlertAction)
  case cancelButtonTapped
  case confirmRemoveCube(LatticePoint)
  case delayedShowUpgradeInterstitial
  case dismissBottomMenu
  case doubleTap(index: LatticePoint)
  case endGameButtonTapped
  case exitButtonTapped
  case forfeitGameButtonTapped
  case gameCenter(GameCenterAction)
  case gameLoaded
  case gameOver(GameOverAction)
  case lowPowerModeChanged(Bool)
  case matchesLoaded(Result<[TurnBasedMatch], NSError>)
  case menuButtonTapped
  case onAppear
  case pan(UIGestureRecognizer.State, PanData?)
  case savedGamesLoaded(Result<SavedGamesState, NSError>)
  case settingsButtonTapped
  case submitButtonTapped(reaction: Move.Reaction?)
  case tap(UIGestureRecognizer.State, IndexedCubeFace?)
  case timerTick(Date)
  case trayButtonTapped
  case upgradeInterstitial(UpgradeInterstitialAction)
  case wordSubmitButton(WordSubmitButtonAction)

  public enum AlertAction: Equatable {
    case dismiss
    case dontForfeitButtonTapped
    case forfeitButtonTapped
  }

  public enum GameCenterAction: Equatable {
    case listener(LocalPlayerClient.ListenerEvent)
    case turnBasedMatchResponse(Result<TurnBasedMatch, NSError>)
  }
}

public struct GameEnvironment {
  public var apiClient: ApiClient
  public var applicationClient: UIApplicationClient
  public var audioPlayer: AudioPlayerClient
  public var backgroundQueue: AnySchedulerOf<DispatchQueue>
  public var build: Build
  public var database: LocalDatabaseClient
  public var dictionary: DictionaryClient
  public var feedbackGenerator: FeedbackGeneratorClient
  public var fileClient: FileClient
  public var gameCenter: GameCenterClient
  public var lowPowerMode: LowPowerModeClient
  public var mainQueue: AnySchedulerOf<DispatchQueue>
  public var mainRunLoop: AnySchedulerOf<RunLoop>
  public var remoteNotifications: RemoteNotificationsClient
  public var serverConfig: ServerConfigClient
  public var setUserInterfaceStyle: (UIUserInterfaceStyle) -> Effect<Never, Never>
  public var storeKit: StoreKitClient
  public var userDefaults: UserDefaultsClient
  public var userNotifications: UserNotificationClient

  public init(
    apiClient: ApiClient,
    applicationClient: UIApplicationClient,
    audioPlayer: AudioPlayerClient,
    backgroundQueue: AnySchedulerOf<DispatchQueue>,
    build: Build,
    database: LocalDatabaseClient,
    dictionary: DictionaryClient,
    feedbackGenerator: FeedbackGeneratorClient,
    fileClient: FileClient,
    gameCenter: GameCenterClient,
    lowPowerMode: LowPowerModeClient,
    mainQueue: AnySchedulerOf<DispatchQueue>,
    mainRunLoop: AnySchedulerOf<RunLoop>,
    remoteNotifications: RemoteNotificationsClient,
    serverConfig: ServerConfigClient,
    setUserInterfaceStyle: @escaping (UIUserInterfaceStyle) -> Effect<Never, Never>,
    storeKit: StoreKitClient,
    userDefaults: UserDefaultsClient,
    userNotifications: UserNotificationClient
  ) {
    self.apiClient = apiClient
    self.applicationClient = applicationClient
    self.audioPlayer = audioPlayer
    self.backgroundQueue = backgroundQueue
    self.build = build
    self.database = database
    self.dictionary = dictionary
    self.feedbackGenerator = feedbackGenerator
    self.fileClient = fileClient
    self.gameCenter = gameCenter
    self.lowPowerMode = lowPowerMode
    self.mainQueue = mainQueue
    self.mainRunLoop = mainRunLoop
    self.remoteNotifications = remoteNotifications
    self.serverConfig = serverConfig
    self.setUserInterfaceStyle = setUserInterfaceStyle
    self.storeKit = storeKit
    self.userDefaults = userDefaults
    self.userNotifications = userNotifications
  }

  func date() -> Date {
    self.mainRunLoop.now.date
  }
}

private struct TimerId: Hashable {}
private struct LowPowerModeId: Hashable {}

public func gameReducer<StatePath, Action, Environment>(
  state: StatePath,
  action: CasePath<Action, GameAction>,
  environment: @escaping (Environment) -> GameEnvironment,
  isHapticsEnabled: @escaping (StatePath.Root) -> Bool
) -> Reducer<StatePath.Root, Action, Environment>
where StatePath: ComposableArchitecture.Path, StatePath.Value == GameState {
  Reducer.combine(
    gameOverReducer
      .optional()
      .pullback(
        state: \.gameOver,
        action: /GameAction.gameOver,
        environment: {
          GameOverEnvironment(
            apiClient: $0.apiClient,
            audioPlayer: $0.audioPlayer,
            database: $0.database,
            fileClient: $0.fileClient,
            mainQueue: $0.mainQueue,
            mainRunLoop: $0.mainRunLoop,
            remoteNotifications: $0.remoteNotifications,
            serverConfig: $0.serverConfig,
            storeKit: $0.storeKit,
            userDefaults: $0.userDefaults,
            userNotifications: $0.userNotifications
          )
        }
      ),

    upgradeInterstitialReducer
      .optional()
      .pullback(
        state: \GameState.upgradeInterstitial,
        action: /GameAction.upgradeInterstitial,
        environment: {
          UpgradeInterstitialEnvironment(
            mainRunLoop: $0.mainRunLoop,
            serverConfig: $0.serverConfig,
            storeKit: $0.storeKit
          )
        }),

    .init { state, action, environment in
      switch action {
      case .activeGames:
        return .none

      case .alert(.dismiss), .alert(.dontForfeitButtonTapped):
        state.alert = nil
        return .none

      case .alert(.forfeitButtonTapped):
        state.alert = nil

        guard let match = state.turnBasedContext?.match
        else { return .none }

        return .merge(
          forceQuitMatch(match: match, gameCenter: environment.gameCenter)
            .fireAndForget(),

          state.gameOver(environment: environment)
        )

      case .cancelButtonTapped:
        state.selectedWord = []
        return .none

      case let .confirmRemoveCube(index):
        state.bottomMenu = nil
        state.removeCube(at: index, playedAt: environment.date())
        state.selectedWord = []
        return .none

      case .delayedShowUpgradeInterstitial:
        state.upgradeInterstitial = .init()
        return .none

      case .dismissBottomMenu:
        state.bottomMenu = nil
        return .none

      case .doubleTap:
        return .none

      case .endGameButtonTapped:
        return state.gameOver(environment: environment)

      case .exitButtonTapped:
        return Effect.gameTearDownEffects(audioPlayer: environment.audioPlayer)
          .fireAndForget()

      case .forfeitGameButtonTapped:
        state.alert = .init(
          title: .init("Are you sure?"),
          message: .init(
            """
            Forfeiting will end the game and your opponent will win. Are you sure you want to forfeit?
            """),
          primaryButton: .default(.init("Don’t forfeit"), send: .dontForfeitButtonTapped),
          secondaryButton: .destructive(.init("Yes, forfeit"), send: .forfeitButtonTapped),
          onDismiss: .dismiss
        )
        return .none

      case .gameCenter:
        return .none

      case .gameLoaded:
        state.isGameLoaded = true
        return Effect<RunLoop.SchedulerTimeType, Never>
          .timer(id: TimerId(), every: 1, on: environment.mainRunLoop)
          .map { GameAction.timerTick($0.date) }

      case .gameOver(.delegate(.close)):
        return Effect.gameTearDownEffects(audioPlayer: environment.audioPlayer)
          .fireAndForget()

      case let .gameOver(.delegate(.startGame(inProgressGame))):
        state = .init(inProgressGame: inProgressGame)
        return .none

      case .gameOver:
        return .none

      case let .lowPowerModeChanged(isOn):
        state.isOnLowPowerMode = isOn
        return .none

      case .matchesLoaded:
        return .none

      case .menuButtonTapped:
        state.bottomMenu = .gameMenu(state: state)
        return .none

      case .onAppear:
        guard !state.isGameOver else { return .none }
        state.gameCurrentTime = environment.date()
        return .onAppearEffects(
          environment: environment,
          gameContext: state.gameContext
        )

      case .pan(.began, _):
        state.isPanning = true
        return .none

      case let .pan(.changed, .some(panData)):
        guard panData.normalizedPoint.isAwayFromCorners else { return .none }

        if let lastLetter = state.selectedWord.last,
          !lastLetter.isTouching(panData.cubeFaceState),
          !state.selectedWord.contains(panData.cubeFaceState)
        {
          return .none
        }

        if let index = state.selectedWord.firstIndex(of: panData.cubeFaceState) {
          state.selectedWord.removeSubrange((index + 1)...)
          return .none
        } else if state.cubes.isPlayable(
          side: panData.cubeFaceState.side, index: panData.cubeFaceState.index)
        {
          state.selectedWord.append(panData.cubeFaceState)
          return .none
        }

        return .none

      case .pan(.cancelled, _), .pan(.ended, .none), .pan(.failed, _):
        state.isPanning = false
        state.selectedWord = []
        return .none

      case .pan:
        state.isPanning = false
        return .none

      case .savedGamesLoaded:
        return .none

      case .settingsButtonTapped:
        state.isSettingsPresented = true
        return .none

      case let .submitButtonTapped(reaction: reaction),
           let .wordSubmitButton(.delegate(.confirmSubmit(reaction: reaction))):
        return state.playSelectedWord(
          with: reaction,
          environment: environment
        )

      case let .tap(.began, face):
        state.optimisticallySelectedFace = nil

        // If tapping off the cube, deselect everything
        guard
          let face = face,
          state.cubes.isPlayable(side: face.side, index: face.index)
        else {
          state.selectedWord = []
          return .none
        }

        // If tapping on a previously selected face then we may back up to that selected face
        if let index = state.selectedWord.firstIndex(of: face) {
          // If not tapping on the last selected face then optimistically back up the selection to that face
          if index != state.selectedWord.endIndex - 1 {
            state.optimisticallySelectedFace = face
            state.selectedWord.removeSubrange((index + 1)...)
          }
        } else {
          // If tapping on a face not connected to the previously selected face, deselect everything
          if let lastLetter = state.selectedWord.last,
            !lastLetter.isTouching(face)
          {
            state.selectedWord = []
          } else {
            state.optimisticallySelectedFace = face
            state.selectedWord.append(face)
          }
        }

        return .none

      case let .tap(.ended, face):
        defer { state.optimisticallySelectedFace = nil }

        guard
          !state.isPanning,
          let face = face,
          face != state.optimisticallySelectedFace,
          state.cubes.isPlayable(side: face.side, index: face.index)
        else {
          return .none
        }

        if let index = state.selectedWord.firstIndex(of: face) {
          // If not tapping on the last selected face then optimistically back up the selection to that face
          state.selectedWord.removeSubrange(index...)
        } else {
          state.selectedWord = []
        }

        return .none

      case .tap(.cancelled, _),
        .tap(.failed, _):
        state.optimisticallySelectedFace = nil
        return .none

      case .tap:
        return .none

      case let .timerTick(time):
        state.gameCurrentTime = time
        if state.isYourTurn && !state.isGameOver {
          state.secondsPlayed += 1
        }
        return .none

      case .trayButtonTapped:
        return .none

      case .upgradeInterstitial(.delegate(.close)),
        .upgradeInterstitial(.delegate(.fullGamePurchased)):
        state.upgradeInterstitial = nil
        return .none

      case .upgradeInterstitial:
        return .none

      case .wordSubmitButton:
        return .none
      }
    }
  )
  .combined(
    with:
      wordSubmitReducer
      .pullback(
        state: \.wordSubmitButtonFeature,
        action: /GameAction.wordSubmitButton,
        environment: {
          .init(
            audioPlayer: $0.audioPlayer,
            feedbackGenerator: $0.feedbackGenerator,
            mainQueue: $0.mainQueue
          )
        }
      )
  )
  .onChange(of: \.selectedWord) { selectedWord, state, _, environment in
    state.selectedWordIsValid =
      !state.selectedWordHasAlreadyBeenPlayed
      && environment.dictionary.contains(state.selectedWordString, state.language)
    return .none
  }
  .combined(with: .removingCubesWithDoubleTap)
  .combined(with: .gameOverAfterRemovingAllCubes)
  .combined(with: .gameOverAfterTimeExpires)
  .combined(with: .turnBasedMatch)
  .combined(with: .activeGamesTray)
  .sounds()
  .filterActionsForYourTurn()
  ._pullback(state: state, action: action, environment: environment)
  .haptics(
    feedbackGenerator: { environment($0).feedbackGenerator },
    isEnabled: isHapticsEnabled,
    triggerOnChangeOf: { state.extract(from: $0)?.selectedWord }
  )
}

extension GameState {
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

  public var isDailyChallenge: Bool {
    self.dailyChallengeId != nil
  }

  public var isGameOver: Bool {
    self.gameOver != nil
  }

  public var isResumable: Bool {
    self.gameMode == .unlimited
      && !self.isGameOver
  }

  public var isSavable: Bool {
    self.isResumable
      && (/GameContext.turnBased).isNotMatching(self.gameContext)
  }

  public var playedWords: [PlayedWord] {
    self.moves
      .reduce(into: [PlayedWord]()) {
        guard case let .playedWord(word) = $1.type else { return }
        $0.append(
          .init(
            isYourWord: $1.playerIndex == self.turnBasedContext?.localPlayerIndex,
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
    self.moves.contains(where: {
      guard case let .playedWord(word) = $0.type else { return false }
      return cubes.string(from: word) == self.selectedWordString
    })
  }

  mutating func tryToRemoveCube(at index: LatticePoint) -> Effect<GameAction, Never> {
    guard self.canRemoveCube else { return .none }

    // Don't show menu for timed games.
    guard self.gameMode != .timed
    else { return .init(value: .confirmRemoveCube(index)) }

    let isTurnEndingRemoval: Bool
    if let turnBasedMatch = self.turnBasedContext,
      let move = self.moves.last,
      case .removedCube = move.type,
      move.playerIndex == turnBasedMatch.localPlayerIndex
    {
      isTurnEndingRemoval = true
    } else {
      isTurnEndingRemoval = false
    }

    self.bottomMenu = .removeCube(
      index: index, state: self, isTurnEndingRemoval: isTurnEndingRemoval)
    return .none
  }

  mutating func removeCube(at index: LatticePoint, playedAt: Date) {
    guard self.cubes[index].isInPlay
    else { return }

    self.cubes[index].wasRemoved = true
    self.moves.append(
      Move(
        playedAt: playedAt,
        playerIndex: self.turnBasedContext?.localPlayerIndex,
        reactions: nil,
        score: 0,
        type: .removedCube(index)
      )
    )
  }

  mutating func playSelectedWord(
    with reaction: Move.Reaction?,
    environment: GameEnvironment
  ) -> Effect<GameAction, Never> {
    let soundEffects: Effect<Never, Never>

    if self.selectedWordIsValid {
      self.moves.append(
        Move(
          playedAt: environment.mainRunLoop.now.date,
          playerIndex: self.turnBasedContext?.localPlayerIndex,
          reactions: zip(self.turnBasedContext?.localPlayerIndex, reaction)
            .map { [$0: $1] },
          score: self.selectedWordScore,
          type: .playedWord(self.selectedWord)
        )
      )

      var removedCubes: [LatticePoint] = []
      self.selectedWord.forEach { cube in
        let wasInPlay = self.cubes[cube.index].isInPlay
        self.cubes[cube.index][cube.side].useCount += 1
        if wasInPlay && !self.cubes[cube.index].isInPlay {
          removedCubes.append(cube.index)
        }
      }

      soundEffects = .merge(
        removedCubes.map { index in
          environment.audioPlayer
            .play(.cubeRemove)
            .debounce(
              id: index,
              for: .milliseconds(removeCubeDelay(index: index)),
              scheduler: environment.mainQueue
            )
            .fireAndForget()
        }
      )
    } else {
      soundEffects = .none
    }

    self.selectedWord = []

    return
      soundEffects
      .fireAndForget()
  }

  mutating func gameOver(environment: GameEnvironment) -> Effect<GameAction, Never> {
    guard !self.isGameOver else { return .none }
    self.bottomMenu = nil
    self.gameOver = GameOverState(
      completedGame: CompletedGame(gameState: self),
      isDemo: self.isDemo
    )

    let saveGameEffect: Effect<GameAction, Never> = environment.database
      .saveGame(.init(gameState: self))
      .fireAndForget()

    switch self.gameContext {
    case .dailyChallenge, .shared, .solo:
      return saveGameEffect

    case let .turnBased(turnBasedMatch):
      self.gameOver?.turnBasedContext = turnBasedMatch
      return .none
    }
  }

  var canRemoveCube: Bool {
    guard let turnBasedMatch = self.turnBasedContext else { return true }
    guard turnBasedMatch.currentParticipantIsLocalPlayer else { return false }
    guard let lastMove = self.moves.last else { return true }
    guard
      (/Move.MoveType.removedCube).isNotMatching(lastMove.type),
      lastMove.playerIndex != turnBasedMatch.localPlayerIndex
    else {
      return true
    }
    return lastMove.playerIndex != turnBasedMatch.localPlayerIndex
  }

  public var isYourTurn: Bool {
    guard let turnBasedMatch = self.turnBasedContext else { return true }
    guard turnBasedMatch.match.status == .open else { return false }
    guard turnBasedMatch.currentParticipantIsLocalPlayer else { return false }
    guard let lastMove = self.moves.last else { return true }
    guard lastMove.playerIndex == turnBasedMatch.localPlayerIndex else { return true }
    guard case .playedWord = lastMove.type else { return true }
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

extension TurnBasedMatchData {
  public init(
    context: TurnBasedContext,
    gameState: GameState,
    playerId: SharedModels.Player.Id?
  ) {
    var metadata = context.metadata
    if let localPlayerIndex = context.localPlayerIndex, let playerId = playerId {
      metadata.playerIndexToId[localPlayerIndex] = playerId
    }
    self.init(
      cubes: ArchivablePuzzle(cubes: gameState.cubes),
      gameMode: gameState.gameMode,
      language: gameState.language,
      metadata: metadata,
      moves: gameState.moves
    )
  }
}

extension BottomMenuState where Action == GameAction {
  public static func removeCube(
    index: LatticePoint,
    state: GameState,
    isTurnEndingRemoval: Bool
  ) -> Self {
    BottomMenuState(
      title: menuTitle(state: state),
      message: isTurnEndingRemoval
        ? .init("Are you sure you want to remove this cube? This will end your turn.")
        : nil,
      footerButton: .init(
        title: isTurnEndingRemoval
          ? .init("Yes, remove cube")
          : .init("Remove cube"),
        icon: .init(systemName: "trash"),
        action: .init(action: .confirmRemoveCube(index), animation: .default)
      ),
      onDismiss: .init(action: .dismissBottomMenu, animation: .default)
    )
  }

  static func gameMenu(state: GameState) -> Self {
    var menu = BottomMenuState(title: menuTitle(state: state))
    menu.onDismiss = .init(action: .dismissBottomMenu, animation: .default)

    if state.isResumable {
      menu.buttons.append(
        .init(
          title: .init("Main menu"),
          icon: .exit,
          action: .init(action: .exitButtonTapped, animation: .default)
        )
      )
    }

    if state.turnBasedContext != nil {
      menu.buttons.append(
        .init(
          title: .init("Forfeit"),
          icon: .flag,
          action: .init(action: .forfeitGameButtonTapped, animation: .default)
        )
      )
    } else {
      menu.buttons.append(
        .init(
          title: .init("End game"),
          icon: .flag,
          action: .init(action: .endGameButtonTapped, animation: .default)
        )
      )
    }

    menu.footerButton = .init(
      title: .init("Settings"),
      icon: Image(systemName: "gear"),
      action: .init(action: .settingsButtonTapped, animation: .default)
    )

    return menu
  }
}

extension Image {
  static let flag = Self(uiImage: UIImage(named: "flag", in: Bundle.module, with: nil)!)
  static let exit = Self(uiImage: UIImage(named: "exit", in: Bundle.module, with: nil)!)
}

func menuTitle(state: GameState) -> TextState {
  .init(state.displayTitle)
}

#if DEBUG
  extension GameEnvironment {
    public static let failing = Self(
      apiClient: .failing,
      applicationClient: .failing,
      audioPlayer: .failing,
      backgroundQueue: .failing("backgroundQueue"),
      build: .failing,
      database: .failing,
      dictionary: .failing,
      feedbackGenerator: .failing,
      fileClient: .failing,
      gameCenter: .failing,
      lowPowerMode: .failing,
      mainQueue: .failing("mainQueue"),
      mainRunLoop: .failing("mainRunLoop"),
      remoteNotifications: .failing,
      serverConfig: .failing,
      setUserInterfaceStyle: { _ in .failing("\(Self.self).setUserInterfaceStyle is unimplemented")
      },
      storeKit: .failing,
      userDefaults: .failing,
      userNotifications: .failing
    )

    public static let noop = Self(
      apiClient: .noop,
      applicationClient: .noop,
      audioPlayer: .noop,
      backgroundQueue: .immediate,
      build: .noop,
      database: .noop,
      dictionary: .everyString,
      feedbackGenerator: .noop,
      fileClient: .noop,
      gameCenter: .noop,
      lowPowerMode: .false,
      mainQueue: .immediate,
      mainRunLoop: .immediate,
      remoteNotifications: .noop,
      serverConfig: .noop,
      setUserInterfaceStyle: { _ in .none },
      storeKit: .noop,
      userDefaults: .noop,
      userNotifications: .noop
    )
  }
#endif

extension Effect where Output == GameAction, Failure == Never {
  static func onAppearEffects(
    environment: GameEnvironment,
    gameContext: ClientModels.GameContext
  ) -> Self {
    .merge(
      environment.lowPowerMode.start
        .receive(on: environment.mainQueue)
        .eraseToEffect()
        .map(GameAction.lowPowerModeChanged)
        .cancellable(id: LowPowerModeId()),

      Effect(value: .gameLoaded)
        .delay(for: 0.5, scheduler: environment.mainQueue)
        .eraseToEffect(),

      gameContext.isTurnBased
        ? Effect<Bool, Error>.showUpgradeInterstitial(
          gameContext: .init(gameContext: gameContext),
          isFullGamePurchased: environment.apiClient.currentPlayer()?.appleReceipt != nil,
          serverConfig: environment.serverConfig.config(),
          playedGamesCount: {
            environment.userDefaults.incrementMultiplayerOpensCount()
              .setFailureType(to: Error.self)
              .eraseToEffect()
          }
        )
        .filter { $0 }
        .delay(for: 3, scheduler: environment.mainRunLoop.animation())
        .map { _ in GameAction.delayedShowUpgradeInterstitial }
        .ignoreFailure()
        .eraseToEffect()
        : .none
    )
  }
}

extension UpgradeInterstitialFeature.GameContext {
  fileprivate init(gameContext: ClientModels.GameContext) {
    switch gameContext {
    case .dailyChallenge:
      self = .dailyChallenge
    case .shared:
      self = .shared
    case .solo:
      self = .solo
    case .turnBased:
      self = .turnBased
    }
  }
}

extension Effect where Output == Never, Failure == Never {
  public static func gameTearDownEffects(audioPlayer: AudioPlayerClient) -> Self {
    .merge(
      .cancel(id: TimerId()),
      .cancel(id: LowPowerModeId()),
      Effect
        .merge(AudioPlayerClient.Sound.allMusic.map(audioPlayer.stop))
        .fireAndForget()
    )
  }
}

extension Reducer where State == GameState, Action == GameAction, Environment == GameEnvironment {
  static let removingCubesWithDoubleTap: Self = Self { state, action, _ in
    guard
      case let .doubleTap(index) = action,
      state.selectedWord.count <= 1
    else { return .none }
    return state.tryToRemoveCube(at: index)
  }

  static let gameOverAfterRemovingAllCubes = Self { state, _, environment in
    // TODO: reconsider this. should only be called once
    let allCubesRemoved = state.cubes.allSatisfy {
      $0.allSatisfy {
        $0.allSatisfy { !$0.isInPlay }
      }
    }

    return allCubesRemoved
      ? state.gameOver(environment: environment)
      : .none
  }

  static let gameOverAfterTimeExpires = Self { state, action, environment in
    switch state.gameMode {
    case .timed:
      return state.secondsPlayed >= state.gameMode.seconds
        ? state.gameOver(environment: environment)
        : .none

    case .unlimited:
      return .none
    }
  }

  static let turnBasedMatch = Self { state, action, environment in
    guard let turnBasedContext = state.turnBasedContext
    else { return .none }

    switch action {
    case let .gameCenter(.listener(.turnBased(.receivedTurnEventForMatch(match, _)))),
      let .gameCenter(.listener(.turnBased(.matchEnded(match)))):

      guard turnBasedContext.match.matchId == match.matchId
      else { return .none }

      guard let turnBasedMatchData = match.matchData?.turnBasedMatchData
      else { return .none }

      state = GameState(
        gameCurrentTime: environment.mainRunLoop.now.date,
        localPlayer: turnBasedContext.localPlayer,
        turnBasedMatch: match,
        turnBasedMatchData: turnBasedMatchData
      )
      state.isGameLoaded = true

      guard
        match.status != .ended,
        match.participants.allSatisfy({ $0.matchOutcome == .none })
      else {
        state.gameOver = .init(
          completedGame: CompletedGame(gameState: state),
          isDemo: state.isDemo,
          turnBasedContext: state.turnBasedContext
        )
        return .merge(
          environment.gameCenter.turnBasedMatch.remove(match)
            .fireAndForget(),

          environment.feedbackGenerator
            .selectionChanged()
            .fireAndForget()
        )
      }

      return environment.feedbackGenerator
        .selectionChanged()
        .fireAndForget()

    case let .gameCenter(.turnBasedMatchResponse(.success(match))):
      guard
        let turnBasedMatchData = match.matchData?.turnBasedMatchData
      else { return .none }

      var gameState = GameState(
        gameCurrentTime: environment.mainRunLoop.now.date,
        localPlayer: environment.gameCenter.localPlayer.localPlayer(),
        turnBasedMatch: match,
        turnBasedMatchData: turnBasedMatchData
      )
      gameState.activeGames = state.activeGames
      gameState.isGameLoaded = state.isGameLoaded
      state = gameState
      return .none

    case .gameCenter(.turnBasedMatchResponse(.failure)):
      return .none

    case .gameOver(.delegate(.close)),
      .exitButtonTapped:
      return .cancel(id: ListenerId())

    case .onAppear:
      return environment.gameCenter.localPlayer.listener
        .map { .gameCenter(.listener($0)) }
        .cancellable(id: ListenerId())

    case .submitButtonTapped,
      .wordSubmitButton(.delegate(.confirmSubmit)),
      .confirmRemoveCube:
      guard
        let move = state.moves.last,
        let localPlayerIndex = turnBasedContext.localPlayerIndex,
        localPlayerIndex == move.playerIndex
      else { return .none }

      let turnBasedMatchData = TurnBasedMatchData(
        context: turnBasedContext,
        gameState: state,
        playerId: environment.apiClient.currentPlayer()?.player.id
      )
      let matchData = Data(turnBasedMatchData: turnBasedMatchData)
      let reloadMatch = environment.gameCenter.turnBasedMatch.load(turnBasedContext.match.matchId)
        .mapError { $0 as NSError }
        .catchToEffect()
        .map { GameAction.gameCenter(.turnBasedMatchResponse($0)) }

      if state.isGameOver {
        let completedGame = CompletedGame(gameState: state)
        guard
          let completedMatch = CompletedMatch(
            completedGame: completedGame,
            turnBasedContext: turnBasedContext
          )
        else { return .none }

        return .concatenate(
          environment.gameCenter.turnBasedMatch
            .endMatchInTurn(
              .init(
                for: turnBasedContext.match.matchId,
                matchData: matchData,
                localPlayerId: turnBasedContext.localPlayer.gamePlayerId,
                localPlayerMatchOutcome: completedMatch.yourOutcome,
                message: "Game over! Let’s see how you did!"
              )
            )
            .fireAndForget(),

          reloadMatch,

          environment.database.saveGame(completedGame)
            .fireAndForget()
        )
      } else {
        switch move.type {
        case .removedCube:
          let shouldEndTurn =
            state.moves.count > 1
            && state.moves[state.moves.count - 2].playerIndex == turnBasedContext.localPlayerIndex

          return .concatenate(
            shouldEndTurn
              ? environment.gameCenter.turnBasedMatch
                .endTurn(
                  .init(
                    for: turnBasedContext.match.matchId,
                    matchData: matchData,
                    message: "\(turnBasedContext.localPlayer.displayName) removed cubes!"
                  )
                )
                .fireAndForget()

              : environment.gameCenter.turnBasedMatch
                .saveCurrentTurn(turnBasedContext.match.matchId, matchData)
                .fireAndForget(),
            reloadMatch
          )
        case let .playedWord(cubeFaces):
          let word = state.cubes.string(from: cubeFaces)
          let score = PuzzleGen.score(word)
          let reaction = (move.reactions?.values.first).map { " \($0.rawValue)" } ?? ""

          return .concatenate(
            environment.gameCenter.turnBasedMatch
              .endTurn(
                .init(
                  for: turnBasedContext.match.matchId,
                  matchData: matchData,
                  message:
                    "\(turnBasedContext.localPlayer.displayName) played \(word)! (+\(score)\(reaction))"
                )
              )
              .fireAndForget(),

            reloadMatch
          )
        }
      }
    default:
      return .none
    }
  }
}

extension CGPoint {
  private static let threshold: CGFloat = 0.35
  private static let thresholdSquared = threshold * threshold
  var isAwayFromCorners: Bool {
    self.x * self.x + self.y * self.y <= Self.thresholdSquared
  }
}

extension CompletedGame {
  public init(gameState: GameState) {
    self.init(
      cubes: .init(cubes: gameState.cubes),
      gameContext: gameState.gameContext.completedGameContext,
      gameMode: gameState.gameMode,
      gameStartTime: gameState.gameStartTime,
      language: gameState.language,
      localPlayerIndex: gameState.turnBasedContext?.localPlayerIndex,
      moves: gameState.moves,
      secondsPlayed: gameState.secondsPlayed
    )
  }
}

struct ListenerId: Hashable {}
