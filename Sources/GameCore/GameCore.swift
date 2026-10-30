import ActiveGamesFeature
import ApiClient
import AudioPlayerClient
import BottomMenu
import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import CubeCore
import Dependencies
import DictionaryClient
import FeedbackGeneratorClient
import FileClient
import GameOverFeature
import HapticsCore
import LowPowerModeClient
import Overture
import ServerConfig
import SettingsFeature
import SharedModels
import SwiftUI
import Tagged
import TcaHelpers
import UpgradeInterstitialFeature
import UserDefaultsClient
import UserSettingsClient

@Feature
public struct Game {
  @Feature public enum Destination {
    case alert(Alert)
    case bottomMenu(BottomMenuPrompt<BottomMenu>)
    case gameOver(GameOver)
    case settings(Settings)
    case upgradeInterstitial(UpgradeInterstitial)

    @Feature public struct Alert: Prompt {
      public struct State {
        public init() {}
      }
      public enum Action {
        case forfeitButtonTapped
      }
    }
    @CasePathable
    public enum BottomMenu {
      case confirmRemoveCube(LatticePoint)
      case endGameButtonTapped
      case exitButtonTapped
      case forfeitGameButtonTapped
      case settingsButtonTapped
    }
  }

  public struct State {
    public var activeGames: ActiveGames.State
    public var cubes: Puzzle
    public var cubeStartedShakingAt: Date?
    public var destination: Destination.State?
    public var gameContext: ClientModels.GameContext
    public var gameCurrentTime: Date
    public var gameMode: GameMode
    public var gameStartTime: Date
    public var enableGyroMotion: Bool
    public var isAnimationReduced: Bool
    public var isDemo: Bool
    public var isGameLoaded: Bool
    public var isOnLowPowerMode: Bool
    public var isPanning: Bool
    public var isTrayVisible: Bool
    public var language: Language
    public var moves: Moves
    public var optimisticallySelectedFace: IndexedCubeFace?
    public var secondsPlayed: Int
    public var selectedWord: [IndexedCubeFace]
    public var selectedWordIsValid: Bool
    public var wordSubmitButton: WordSubmitButtonFeature.ButtonState

    public init(
      activeGames: ActiveGames.State = .init(),
      cubes: Puzzle,
      cubeStartedShakingAt: Date? = nil,
      destination: Destination.State? = nil,
      gameContext: ClientModels.GameContext,
      gameCurrentTime: Date,
      gameMode: GameMode,
      gameStartTime: Date,
      isDemo: Bool = false,
      isGameLoaded: Bool = false,
      isPanning: Bool = false,
      isOnLowPowerMode: Bool = false,
      isTrayVisible: Bool = false,
      language: Language = .en,
      moves: Moves = [],
      optimisticallySelectedFace: IndexedCubeFace? = nil,
      secondsPlayed: Int = 0,
      selectedWord: [IndexedCubeFace] = [],
      selectedWordIsValid: Bool = false,
      wordSubmit: WordSubmitButtonFeature.ButtonState = .init()
    ) {
      @Dependency(\.userSettings) var userSettings
      self.activeGames = activeGames
      self.cubes = cubes
      self.cubeStartedShakingAt = cubeStartedShakingAt
      self.destination = destination
      self.enableGyroMotion = userSettings.enableGyroMotion
      self.gameContext = gameContext
      self.gameCurrentTime = gameCurrentTime
      self.gameMode = gameMode
      self.gameStartTime = gameStartTime
      self.isAnimationReduced = userSettings.enableReducedAnimation
      self.isDemo = isDemo
      self.isGameLoaded = isGameLoaded
      self.isOnLowPowerMode = isOnLowPowerMode
      self.isPanning = isPanning
      self.isTrayVisible = isTrayVisible
      self.language = language
      self.moves = moves
      self.optimisticallySelectedFace = optimisticallySelectedFace
      self.secondsPlayed = secondsPlayed
      self.selectedWord = selectedWord
      self.selectedWordIsValid = selectedWordIsValid
      self.wordSubmitButton = wordSubmit
    }

    public var isNavVisible: Bool {
      !self.isDemo
    }

    public var isTrayAvailable: Bool {
      self.gameMode != .timed && !self.activeGames.isEmpty
    }

    public var wordSubmitButtonFeature: WordSubmitButtonFeature.State {
      get {
        .init(
          isSelectedWordValid: self.selectedWordIsValid,
          isTurnBasedMatch: self.gameContext.is(\.turnBased),
          isYourTurn: self.gameContext.turnBased?.currentParticipantIsLocalPlayer ?? true,
          wordSubmitButton: self.wordSubmitButton
        )
      }
      set {
        self.wordSubmitButton = newValue.wordSubmitButton
      }
    }
  }

  public enum Action {
    case activeGames(ActiveGames.Action)
    case cancelButtonTapped
    case confirmRemoveCube(LatticePoint)
    case destination(Destination.Action)
    case doubleTap(index: LatticePoint)
    case menuButtonTapped
    case pan(UIGestureRecognizer.State, PanData?)
    case submitButtonTapped(reaction: Move.Reaction?)
    case tap(UIGestureRecognizer.State, IndexedCubeFace?)
    case trayButtonTapped
    case wordSubmitButton(WordSubmitButtonFeature.Action)
  }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.audioPlayer) var audioPlayer
  @FeatureEnvironment(\.date) var date
  @Dependency(\.dictionary.contains) var dictionaryContains
  @Dependency(\.feedbackGenerator) var feedbackGenerator
  @Dependency(\.fileClient) var fileClient
  @Dependency(\.gameCenter) var gameCenter
  @Dependency(\.lowPowerMode) var lowPowerMode
  @FeatureEnvironment(\.continuousClock) var clock
  @Dependency(\.database.saveGame) var saveGame
  @Dependency(\.serverConfig.config) var serverConfig
  @Dependency(\.userDefaults) var userDefaults
  @Dependency(\.userSettings) var userSettings

  @FeatureBindable var store = FeatureStore<State, Action>()
  @StoreTaskID var cubeShaking
  @FeatureState var isSubmittingWord = false

  let startsOnMount: Bool

  public init(startsOnMount: Bool = true) {
    self.startsOnMount = startsOnMount
  }

  var now: Date { self.date.now }

  public var body: some Feature {
    Update { state, action in
      guard !action.requiresYourTurn || state.isYourTurn else { return }
      self.isSubmittingWord = action.is(\.submitButtonTapped)
      self.core(state: &state, action: action)
      self.turnBased(state: &state, action: action)
      self.activeGamesTray(state: &state, action: action)
      self.sounds(state: &state, action: action)
    }
    .ifLet(\.destination) {
      Destination.body
    }
    .onEvent(GameOver.Event.self) { event, state -> FeatureEventPropagation in
      switch event {
      case .dismissGame:
        guard store.isPresented else { return .continue }
        store.addTask {
          try withAnimation {
            _ = try store.dismiss()
          }
        }
        return .stop

      case .startGame(let inProgressGame):
        let activeGames = state.activeGames
        let isGameLoaded = state.isGameLoaded
        state = .init(inProgressGame: inProgressGame)
        state.activeGames = activeGames
        state.isGameLoaded = isGameLoaded
        return .stop

      case .gameSubmitted, .rematch, .startSoloGame:
        return .continue
      }
    }
    .onEvent(UpgradeInterstitial.FullGamePurchased.self) { _, _ in }
    Scope(\.wordSubmitButtonFeature) {
      WordSubmitButtonFeature()
    }
    .onEvent(WordSubmitButtonFeature.ConfirmSubmit.self) { reaction, _ in
      store.addTask {
        try withAnimation {
          _ = try store.send(.submitButtonTapped(reaction: reaction))
        }
      }
    }
    Scope(\.activeGames) {
      ActiveGames()
    }
    Update { _, _ in }
      .onChange(of: store.selectedWord) { previousSelection, selectedWord, state in
        state.selectedWordIsValid =
          !state.selectedWordHasAlreadyBeenPlayed
          && self.dictionaryContains(state.selectedWordString, state.language)
        self.selectedWordChanged(from: previousSelection, to: selectedWord, state: &state)
      }
      .onChange(of: store.isOutOfTimeOrCubes, initial: true) { _, isOutOfTimeOrCubes, state in
        guard isOutOfTimeOrCubes else { return }
        self.endGame(state: &state)
      }
      .onChange(of: store.isGameOver) { _, _, _ in
        self.gameOverChanged()
      }
      .onChange(of: store.secondsPlayed) { _, secondsPlayed, state in
        self.secondsPlayedChanged(secondsPlayed, state: state)
      }
      .onChange(of: store.moves.last) { _, lastMove, state in
        self.lastMoveChanged(lastMove, state: state)
      }
      .selectionSounds(
        contains: { self.dictionaryContains($1, $0.language) },
        hasBeenPlayed: { $0.hasBeenPlayed(word: $1) },
        puzzle: \.cubes,
        selectedWord: store.selectedWord
      )
      .onMount { state in
        guard self.startsOnMount else { return }
        self.mountSounds(state: state)
        self.mountTurnBased()
        self.loadActiveGames()
        self.mountCore(state: &state)
      }
      .onDismount {
        guard self.startsOnMount else { return }
        for music in AudioPlayerClient.Sound.allMusic {
          await self.audioPlayer.stop(music)
        }
      }
  }

  private func core(state: inout State, action: Action) {
    switch action {
    case .activeGames:
      break

    case .cancelButtonTapped:
      state.selectedWord = []

    case .confirmRemoveCube(let index):
      state.removeCube(at: index, playedAt: self.now)

    case .destination(.alert(.forfeitButtonTapped)):
      self.endGame(state: &state)
      guard let match = state.gameContext.turnBased?.match
      else { return }

      store.addTask {
        let localPlayer = self.gameCenter.localPlayer.localPlayer()
        let currentParticipantIsLocalPlayer =
          match.currentParticipant?.player?.gamePlayerId == localPlayer.gamePlayerId

        if currentParticipantIsLocalPlayer {
          try await self.gameCenter.turnBasedMatch.endMatchInTurn(
            .init(
              for: match.matchId,
              matchData: match.matchData ?? Data(),
              localPlayerId: localPlayer.gamePlayerId,
              localPlayerMatchOutcome: .quit,
              message: "\(localPlayer.displayName) forfeited the match."
            )
          )
        } else {
          try await self.gameCenter.turnBasedMatch
            .participantQuitOutOfTurn(match.matchId)
        }
      }

    case .destination(.bottomMenu(.confirmRemoveCube(let index))):
      state.removeCube(at: index, playedAt: self.now)

    case .destination(.bottomMenu(.endGameButtonTapped)):
      self.endGame(state: &state)

    case .destination(.bottomMenu(.exitButtonTapped)):
      store.addTask {
        try withAnimation {
          _ = try store.dismiss()
        }
      }

    case .destination(.bottomMenu(.forfeitGameButtonTapped)):
      state.destination = .alert(Destination.Alert.State())

    case .destination(.bottomMenu(.settingsButtonTapped)):
      state.destination = .settings(Settings.State())

    case .destination:
      break

    case .doubleTap(let index):
      guard state.selectedWord.count <= 1
      else { return }

      if state.tryToRemoveCube(at: index) {
        store.addTask {
          try store.send(.confirmRemoveCube(index))
        }
      }

    case .menuButtonTapped:
      state.destination = .bottomMenu(.gameMenu(state: state))

    case .pan(.began, _):
      state.isPanning = true

    case .pan(.changed, .some(let panData)):
      guard panData.normalizedPoint.isAwayFromCorners else { return }

      if let lastLetter = state.selectedWord.last,
        !lastLetter.isTouching(panData.cubeFaceState),
        !state.selectedWord.contains(panData.cubeFaceState)
      {
        return
      }

      if let index = state.selectedWord.firstIndex(of: panData.cubeFaceState) {
        state.selectedWord.removeSubrange((index + 1)...)
      } else if state.cubes.isPlayable(
        side: panData.cubeFaceState.side,
        index: panData.cubeFaceState.index
      ) {
        state.selectedWord.append(panData.cubeFaceState)
      }

    case .pan(.cancelled, _), .pan(.ended, .none), .pan(.failed, _):
      state.isPanning = false
      state.selectedWord = []

    case .pan:
      state.isPanning = false

    case .submitButtonTapped(reaction: let reaction):
      let move = Move(
        playedAt: self.now,
        playerIndex: state.gameContext.turnBased?.localPlayerIndex,
        reactions: zip(state.gameContext.turnBased?.localPlayerIndex, reaction)
          .map { [$0: $1] },
        score: state.selectedWordScore,
        type: .playedWord(state.selectedWord)
      )

      var cubes = state.cubes
      let result = verify(
        move: move,
        on: &cubes,
        isValidWord: { self.dictionaryContains($0, state.language) },
        previousMoves: state.moves
      )
      state.cubes = cubes

      defer { state.selectedWord = [] }

      guard result != nil else { return }

      state.moves.append(move)

      let removedFaces = state.selectedWord.filter { !state.cubes[$0.index].isInPlay }
      store.addTask {
        await withThrowingTaskGroup(of: Void.self) { group in
          for face in removedFaces {
            group.addTask {
              try await self.clock
                .sleep(for: .milliseconds(removeCubeDelay(index: face.index)))
              await self.audioPlayer.play(.cubeRemove)
            }
          }
        }
      }

    case .tap(.began, let face):
      state.optimisticallySelectedFace = nil

      // If tapping off the cube, deselect everything
      guard
        let face = face,
        state.cubes.isPlayable(side: face.side, index: face.index)
      else {
        state.selectedWord = []
        return
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

    case .tap(.ended, let face):
      defer { state.optimisticallySelectedFace = nil }

      guard
        !state.isPanning,
        let face = face,
        face != state.optimisticallySelectedFace,
        state.cubes.isPlayable(side: face.side, index: face.index)
      else {
        return
      }

      if let index = state.selectedWord.firstIndex(of: face) {
        // If not tapping on the last selected face then optimistically back up the selection to that face
        state.selectedWord.removeSubrange(index...)
      } else {
        state.selectedWord = []
      }

    case .tap(.cancelled, _),
      .tap(.failed, _):
      state.optimisticallySelectedFace = nil

    case .tap:
      break

    case .trayButtonTapped:
      break

    case .wordSubmitButton:
      break
    }
  }

  private func mountCore(state: inout State) {
    guard !state.isGameOver else { return }
    state.gameCurrentTime = self.now

    store.addTask {
      for await isLowPower in await self.lowPowerMode.start() {
        try store.modify { $0.isOnLowPowerMode = isLowPower }
      }
    }

    if state.gameContext.is(\.turnBased) {
      let gameContext = state.gameContext
      store.addTask {
        let playedGamesCount = await self.userDefaults
          .incrementMultiplayerOpensCount()
        let isFullGamePurchased = self.apiClient.currentPlayer()?.appleReceipt != nil
        guard
          !isFullGamePurchased,
          shouldShowInterstitial(
            gamePlayedCount: playedGamesCount,
            gameContext: .init(gameContext: gameContext),
            serverConfig: self.serverConfig()
          )
        else { return }
        try await self.clock.sleep(for: .seconds(3))
        try withAnimation {
          _ = try store.modify {
            $0.destination = .upgradeInterstitial(UpgradeInterstitial.State())
          }
        }
      }
    }

    store.addTask {
      try await self.clock.sleep(for: .seconds(0.5))
      try store.modify { $0.isGameLoaded = true }
      for await _ in self.clock.timer(interval: .seconds(1)) {
        try store.modify {
          $0.gameCurrentTime = self.now
          if $0.isYourTurn && !$0.isGameOver {
            $0.secondsPlayed += 1
          }
        }
      }
    }

    store.addTask {
      for await userSettings in self.userSettings.stream() {
        try store.modify {
          $0.enableGyroMotion = userSettings.enableGyroMotion
          $0.isAnimationReduced = userSettings.enableReducedAnimation
        }
      }
    }
  }
}

extension Game.Scopes {
  public var wordSubmitButtonFeature: WordSubmitButtonFeatureScope {
    WordSubmitButtonFeatureScope()
  }

  public struct WordSubmitButtonFeatureScope: ScopePath {
    public let statePath = \Game.State.wordSubmitButtonFeature
    public let actionPath = \Game.Action.Cases.wordSubmitButton
  }
}

extension Game.Action {
  var requiresYourTurn: Bool {
    switch self {
    case .pan, .submitButtonTapped, .tap:
      return true
    default:
      return false
    }
  }
}

extension TurnBasedMatchData {
  public init(
    context: TurnBasedContext,
    gameState: Game.State,
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

extension BottomMenuPrompt.State where MenuAction == Game.Destination.BottomMenu {
  public static func removeCube(
    index: LatticePoint,
    state: Game.State,
    isTurnEndingRemoval: Bool
  ) -> Self {
    Self(
      title: menuTitle(state: state),
      message: isTurnEndingRemoval
        ? Text("Are you sure you want to remove this cube? This will end your turn.")
        : nil,
      footerButton: .init(
        title: isTurnEndingRemoval
          ? Text("Yes, remove cube")
          : Text("Remove cube"),
        icon: .init(systemName: "trash"),
        action: .init(action: .confirmRemoveCube(index), animation: .default)
      )
    )
  }

  public static func gameMenu(state: Game.State) -> Self {
    var menu = Self(title: menuTitle(state: state))

    if state.isResumable {
      menu.buttons.append(
        .init(
          title: Text("Main menu"),
          icon: .exit,
          action: .init(action: .exitButtonTapped, animation: .default)
        )
      )
    }

    if state.gameContext.turnBased != nil {
      menu.buttons.append(
        .init(
          title: Text("Forfeit"),
          icon: .flag,
          action: .init(action: .forfeitGameButtonTapped, animation: .default)
        )
      )
    } else {
      menu.buttons.append(
        .init(
          title: Text("End game"),
          icon: .flag,
          action: .init(action: .endGameButtonTapped, animation: .default)
        )
      )
    }

    menu.footerButton = .init(
      title: Text("Settings"),
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

func menuTitle(state: Game.State) -> Text {
  Text(state.displayTitle)
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

extension CGPoint {
  private static let threshold: CGFloat = 0.35
  private static let thresholdSquared = threshold * threshold
  var isAwayFromCorners: Bool {
    self.x * self.x + self.y * self.y <= Self.thresholdSquared
  }
}

extension CompletedGame {
  public init(gameState: Game.State) {
    self.init(
      cubes: .init(cubes: gameState.cubes),
      gameContext: gameState.gameContext.completedGameContext,
      gameMode: gameState.gameMode,
      gameStartTime: gameState.gameStartTime,
      language: gameState.language,
      localPlayerIndex: gameState.gameContext.turnBased?.localPlayerIndex,
      moves: gameState.moves,
      secondsPlayed: gameState.secondsPlayed
    )
  }
}

extension DependencyValues {
  public mutating func gameOnboarding() {
    let previousValues = self

    self = Self.test
    self.apiClient = .noop
    self.audioPlayer = previousValues.audioPlayer
    self.build = .noop
    self.database = .noop
    self.dictionary = previousValues.dictionary
    self.feedbackGenerator = previousValues.feedbackGenerator
    self.fileClient = .noop
    self.gameCenter = .noop
    self.remoteNotifications = .noop
    self.serverConfig = .noop
    self.storeKit = .noop
    self.userNotifications = .noop
  }
}
