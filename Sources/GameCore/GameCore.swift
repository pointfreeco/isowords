import ActiveGamesFeature
import AudioPlayerClient
import BottomMenu
import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import CubeCore
import DictionaryClient
import GameOverFeature
import HapticsCore
import LowPowerModeClient
import Overture
import SettingsFeature
import SharedModels
import SwiftUI
import Tagged
import TcaHelpers
import UpgradeInterstitialFeature
import UserSettingsClient

@Reducer
public struct Game {
  @Reducer
  public struct Destination {
    public enum State: Equatable {
      case alert(AlertState<Action.Alert>)
      case bottomMenu(BottomMenuState<Action.BottomMenu>)
      case gameOver(GameOver.State)
      case settings(Settings.State = Settings.State())
      case upgradeInterstitial(UpgradeInterstitial.State = .init())
    }

    public enum Action {
      case alert(Alert)
      case bottomMenu(BottomMenu)
      case gameOver(GameOver.Action)
      case settings(Settings.Action)
      case upgradeInterstitial(UpgradeInterstitial.Action)

      @CasePathable
      public enum Alert {
        case forfeitButtonTapped
      }
      @CasePathable
      public enum BottomMenu: Equatable {
        case confirmRemoveCube(LatticePoint)
        case endGameButtonTapped
        case exitButtonTapped
        case forfeitGameButtonTapped
        case settingsButtonTapped
      }
    }

    let dismissGame: DismissEffect

    public var body: some ReducerOf<Self> {
      Scope(state: \.gameOver, action: \.gameOver) {
        GameOver()
          .dependency(\.dismiss, self.dismissGame)
      }
      Scope(state: \.settings, action: \.settings) {
        Settings()
      }
      Scope(state: \.upgradeInterstitial, action: \.upgradeInterstitial) {
        UpgradeInterstitial()
      }
    }
  }

  public struct State: Equatable {
    public var activeGames: ActiveGamesState
    public var cubes: Puzzle
    public var cubeStartedShakingAt: Date?
    @PresentationState public var destination: Destination.State?
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
      activeGames: ActiveGamesState = .init(),
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
    case activeGames(ActiveGamesAction)
    case cancelButtonTapped
    case confirmRemoveCube(LatticePoint)
    case delayedShowUpgradeInterstitial
    case destination(PresentationAction<Destination.Action>)
    case doubleTap(index: LatticePoint)
    case gameCenter(GameCenterAction)
    case gameLoaded
    case lowPowerModeChanged(Bool)
    case matchesLoaded(Result<[TurnBasedMatch], Error>)
    case menuButtonTapped
    case task
    case pan(UIGestureRecognizer.State, PanData?)
    case savedGamesLoaded(Result<SavedGamesState, Error>)
    case submitButtonTapped(reaction: Move.Reaction?)
    case tap(UIGestureRecognizer.State, IndexedCubeFace?)
    case timerTick(Date)
    case trayButtonTapped
    case userSettingsUpdated(UserSettings)
    case wordSubmitButton(WordSubmitButtonFeature.Action)
  }

  @CasePathable
  public enum GameCenterAction {
    case listener(LocalPlayerClient.ListenerEvent)
    case turnBasedMatchResponse(Result<TurnBasedMatch, Error>)
  }

  @Dependency(\.audioPlayer) var audioPlayer
  @Dependency(\.apiClient.currentPlayer) var currentPlayer
  @Dependency(\.dismiss) var dismiss
  @Dependency(\.dictionary.contains) var dictionaryContains
  @Dependency(\.gameCenter) var gameCenter
  @Dependency(\.lowPowerMode) var lowPowerMode
  @Dependency(\.mainQueue) var mainQueue
  @Dependency(\.mainRunLoop) var mainRunLoop
  @Dependency(\.serverConfig.config) var serverConfig
  @Dependency(\.userDefaults) var userDefaults
  @Dependency(\.userSettings) var userSettings

  public init() {}

  func date() -> Date { self.mainRunLoop.now.date }

  public var body: some Reducer<State, Action> {
    self.core
      .onChange(of: \.selectedWord) { _, selectedWord in
        Reduce { state, _ in
          state.selectedWordIsValid =
            !state.selectedWordHasAlreadyBeenPlayed
            && self.dictionaryContains(state.selectedWordString, state.language)
          return .none
        }
      }
      .filterActionsForYourTurn()
      .ifLet(\.$destination, action: \.destination) {
        Destination(dismissGame: self.dismiss)
      }
      .sounds()
  }

  @ReducerBuilder<State, Action>
  var core: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .activeGames:
        return .none

      case .cancelButtonTapped:
        state.selectedWord = []
        return .none

      case let .confirmRemoveCube(index):
        state.removeCube(at: index, playedAt: self.date())
        return .none

      case .delayedShowUpgradeInterstitial:
        state.destination = .upgradeInterstitial()
        return .none

      case .destination(.presented(.alert(.forfeitButtonTapped))):
        guard let match = state.gameContext.turnBased?.match
        else { return .none }

        return .run { _ in
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

      case let .destination(.presented(.bottomMenu(.confirmRemoveCube(index)))):
        state.removeCube(at: index, playedAt: self.date())
        return .none

      case .destination(.presented(.bottomMenu(.exitButtonTapped))):
        return .run { _ in
          await self.dismiss(animation: .default)
        }

      case .destination(.presented(.bottomMenu(.forfeitGameButtonTapped))):
        state.destination = .alert(
          AlertState {
            TextState("Are you sure?")
          } actions: {
            ButtonState(role: .cancel) {
              TextState("Don't forfeit")
            }
            ButtonState(role: .destructive, action: .forfeitButtonTapped) {
              TextState("Yes, forfeit")
            }
          } message: {
            TextState(
              """
              Forfeiting will end the game and your opponent will win. Are you sure you want to \
              forfeit?
              """
            )
          }
        )
        return .none

      case .destination(.presented(.bottomMenu(.settingsButtonTapped))):
        state.destination = .settings()
        return .none

      case let .destination(.presented(.gameOver(.delegate(.startGame(inProgressGame))))):
        state = .init(inProgressGame: inProgressGame)
        return .none

      case .destination:
        return .none

      case let .doubleTap(index):
        guard state.selectedWord.count <= 1
        else { return .none }

        return state.tryToRemoveCube(at: index)

      case .gameCenter:
        return .none

      case .gameLoaded:
        state.isGameLoaded = true
        return .run { send in
          for await instant in self.mainRunLoop.timer(interval: .seconds(1)) {
            await send(.timerTick(instant.date))
          }
        }

      case let .lowPowerModeChanged(isOn):
        state.isOnLowPowerMode = isOn
        return .none

      case .matchesLoaded:
        return .none

      case .menuButtonTapped:
        state.destination = .bottomMenu(.gameMenu(state: state))
        return .none

      case .task:
        guard !state.isGameOver else { return .none }
        state.gameCurrentTime = self.date()

        return .run { [gameContext = state.gameContext] send in
          await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
              for await isLowPower in await self.lowPowerMode.start() {
                await send(.lowPowerModeChanged(isLowPower))
              }
            }

            if gameContext.is(\.turnBased) {
              group.addTask {
                let playedGamesCount = await self.userDefaults
                  .incrementMultiplayerOpensCount()
                let isFullGamePurchased = self.currentPlayer()?.appleReceipt != nil
                guard
                  !isFullGamePurchased,
                  shouldShowInterstitial(
                    gamePlayedCount: playedGamesCount,
                    gameContext: .init(gameContext: gameContext),
                    serverConfig: self.serverConfig()
                  )
                else { return }
                try await self.mainRunLoop.sleep(for: .seconds(3))
                await send(.delayedShowUpgradeInterstitial, animation: .default)
              }
            }

            group.addTask {
              try await self.mainQueue.sleep(for: 0.5)
              await send(.gameLoaded)
            }

            group.addTask {
              for await userSettings in self.userSettings.stream() {
                await send(.userSettingsUpdated(userSettings))
              }
            }
          }
          for music in AudioPlayerClient.Sound.allMusic {
            await self.audioPlayer.stop(music)
          }
        }

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

      case let .submitButtonTapped(reaction: reaction),
        let .wordSubmitButton(.delegate(.confirmSubmit(reaction: reaction))):

        let move = Move(
          playedAt: self.mainRunLoop.now.date,
          playerIndex: state.gameContext.turnBased?.localPlayerIndex,
          reactions: zip(state.gameContext.turnBased?.localPlayerIndex, reaction)
            .map { [$0: $1] },
          score: state.selectedWordScore,
          type: .playedWord(state.selectedWord)
        )

        let result = verify(
          move: move,
          on: &state.cubes,
          isValidWord: { self.dictionaryContains($0, state.language) },
          previousMoves: state.moves
        )

        defer { state.selectedWord = [] }

        guard result != nil else { return .none }

        state.moves.append(move)

        return .run { [state] _ in
          await withThrowingTaskGroup(of: Void.self) { group in
            for face in state.selectedWord where !state.cubes[face.index].isInPlay {
              group.addTask {
                try await self.mainQueue
                  .sleep(for: .milliseconds(removeCubeDelay(index: face.index)))
                await self.audioPlayer.play(.cubeRemove)
              }
            }
          }
        }

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

      case let .userSettingsUpdated(userSettings):
        state.enableGyroMotion = userSettings.enableGyroMotion
        state.isAnimationReduced = userSettings.enableReducedAnimation
        return .none

      case .wordSubmitButton:
        return .none
      }
    }
    Scope(state: \.wordSubmitButtonFeature, action: \.wordSubmitButton) {
      WordSubmitButtonFeature()
    }
    GameOverLogic()
    TurnBasedLogic()
    ActiveGamesTray()
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

extension BottomMenuState where Action == Game.Destination.Action.BottomMenu {
  public static func removeCube(
    index: LatticePoint,
    state: Game.State,
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
      )
    )
  }

  public static func gameMenu(state: Game.State) -> Self {
    var menu = BottomMenuState(title: menuTitle(state: state))

    if state.isResumable {
      menu.buttons.append(
        .init(
          title: .init("Main menu"),
          icon: .exit,
          action: .init(action: .exitButtonTapped, animation: .default)
        )
      )
    }

    if state.gameContext.turnBased != nil {
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

func menuTitle(state: Game.State) -> TextState {
  .init(state.displayTitle)
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
    self.date = previousValues.date
    self.dictionary = previousValues.dictionary
    self.feedbackGenerator = previousValues.feedbackGenerator
    self.fileClient = .noop
    self.gameCenter = .noop
    self.mainRunLoop = previousValues.mainRunLoop
    self.mainQueue = previousValues.mainQueue
    self.remoteNotifications = .noop
    self.serverConfig = .noop
    self.storeKit = .noop
    self.userNotifications = .noop
  }
}
