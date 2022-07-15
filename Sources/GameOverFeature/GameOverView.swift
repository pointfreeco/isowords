import ApiClient
import AudioPlayerClient
import ClientModels
import Combine
import CombineHelpers
import ComposableArchitecture
import ComposableGameCenter
import ComposableStoreKit
import ComposableUserNotifications
import DailyChallengeHelpers
import FileClient
import GameKit
import LocalDatabaseClient
import NotificationHelpers
import NotificationsAuthAlert
import Overture
import RemoteNotificationsClient
import ServerConfig
import ServerConfigClient
import SharedModels
import SharedSwiftUIEnvironment
import Styleguide
import SwiftUI
import SwiftUIHelpers
import TcaHelpers
import UpgradeInterstitialFeature
import UserDefaultsClient

public struct GameOverState: Equatable {
  public var completedGame: CompletedGame
  public var dailyChallenges: [FetchTodaysDailyChallengeResponse]
  public var gameModeIsLoading: GameMode?
  public var isDemo: Bool
  public var isNotificationMenuPresented: Bool
  public var isViewEnabled: Bool
  public var notificationsAuthAlert: NotificationsAuthAlertState?
  public var showConfetti: Bool
  public var summary: RankSummary?
  public var turnBasedContext: TurnBasedContext?
  public var upgradeInterstitial: UpgradeInterstitialState?
  public var userNotificationSettings: UserNotificationClient.Notification.Settings?

  public init(
    completedGame: CompletedGame,
    dailyChallenges: [FetchTodaysDailyChallengeResponse] = [],
    gameModeIsLoading: GameMode? = nil,
    isDemo: Bool,
    isNotificationMenuPresented: Bool = false,
    isViewEnabled: Bool = false,
    notificationsAuthAlert: NotificationsAuthAlertState? = nil,
    showConfetti: Bool = false,
    summary: RankSummary? = nil,
    turnBasedContext: TurnBasedContext? = nil,
    upgradeInterstitial: UpgradeInterstitialState? = nil,
    userNotificationSettings: UserNotificationClient.Notification.Settings? = nil
  ) {
    self.completedGame = completedGame
    self.dailyChallenges = dailyChallenges
    self.gameModeIsLoading = gameModeIsLoading
    self.isDemo = isDemo
    self.isNotificationMenuPresented = isNotificationMenuPresented
    self.isViewEnabled = isViewEnabled
    self.notificationsAuthAlert = notificationsAuthAlert
    self.showConfetti = showConfetti
    self.summary = summary
    self.turnBasedContext = turnBasedContext
    self.upgradeInterstitial = upgradeInterstitial
    self.userNotificationSettings = userNotificationSettings
  }

  public enum RankSummary: Equatable {
    case dailyChallenge(DailyChallengeResult)
    case leaderboard([TimeScope: LeaderboardScoreResult.Rank])
  }
}

public enum GameOverAction: Equatable {
  case closeButtonTapped
  case dailyChallengeResponse(TaskResult<[FetchTodaysDailyChallengeResponse]>)
  case delayedOnAppear
  case delayedShowUpgradeInterstitial
  case delegate(DelegateAction)
  case gameButtonTapped(GameMode)
  case onAppear
  case notificationsAuthAlert(NotificationsAuthAlertAction)
  case rematchButtonTapped
  case showConfetti
  case startDailyChallengeResponse(TaskResult<InProgressGame>)
  case submitGameResponse(TaskResult<SubmitGameResponse>)
  case upgradeInterstitial(UpgradeInterstitialAction)
  case userNotificationSettingsResponse(UserNotificationClient.Notification.Settings)

  public enum DelegateAction: Equatable {
    case close
    case startGame(InProgressGame)
    case startSoloGame(GameMode)
  }
}

public struct GameOverEnvironment {
  public var apiClient: ApiClient
  public var audioPlayer: AudioPlayerClient
  public var database: LocalDatabaseClient
  public var fileClient: FileClient
  public var mainRunLoop: AnySchedulerOf<RunLoop>
  public var remoteNotifications: RemoteNotificationsClient
  public var serverConfig: ServerConfigClient
  public var storeKit: StoreKitClient
  public var userDefaults: UserDefaultsClient
  public var userNotifications: UserNotificationClient

  public init(
    apiClient: ApiClient,
    audioPlayer: AudioPlayerClient,
    database: LocalDatabaseClient,
    fileClient: FileClient,
    mainRunLoop: AnySchedulerOf<RunLoop>,
    remoteNotifications: RemoteNotificationsClient,
    serverConfig: ServerConfigClient,
    storeKit: StoreKitClient,
    userDefaults: UserDefaultsClient,
    userNotifications: UserNotificationClient
  ) {
    self.apiClient = apiClient
    self.audioPlayer = audioPlayer
    self.database = database
    self.fileClient = fileClient
    self.mainRunLoop = mainRunLoop
    self.remoteNotifications = remoteNotifications
    self.serverConfig = serverConfig
    self.storeKit = storeKit
    self.userDefaults = userDefaults
    self.userNotifications = userNotifications
  }

  #if DEBUG
    public static let failing = Self(
      apiClient: .failing,
      audioPlayer: .failing,
      database: .failing,
      fileClient: .failing,
      mainRunLoop: .failing,
      remoteNotifications: .failing,
      serverConfig: .failing,
      storeKit: .failing,
      userDefaults: .failing,
      userNotifications: .failing
    )
  #endif
}

public let gameOverReducer = Reducer<GameOverState, GameOverAction, GameOverEnvironment>.combine(
  notificationsAuthAlertReducer
    .optional()
    .pullback(
      state: \.notificationsAuthAlert,
      action: /GameOverAction.notificationsAuthAlert,
      environment: {
        NotificationsAuthAlertEnvironment(
          mainRunLoop: $0.mainRunLoop,
          remoteNotifications: $0.remoteNotifications,
          userNotifications: $0.userNotifications
        )
      }
    ),

  upgradeInterstitialReducer
    .optional()
    .pullback(
      state: \.upgradeInterstitial,
      action: /GameOverAction.upgradeInterstitial,
      environment: {
        UpgradeInterstitialEnvironment(
          mainRunLoop: $0.mainRunLoop,
          serverConfig: $0.serverConfig,
          storeKit: $0.storeKit
        )
      }
    ),

  Reducer { state, action, environment in
    switch action {
    case .closeButtonTapped:
      guard
        [.notDetermined, .provisional]
          .contains(state.userNotificationSettings?.authorizationStatus),
        case .dailyChallenge = state.completedGame.gameContext
      else {
        return .run { send in
          await send(.delegate(.close))
          try? await environment.requestReviewAsync()
        }
      }

      state.notificationsAuthAlert = .init()
      return .none

    case .dailyChallengeResponse(.failure):
      return .none

    case let .dailyChallengeResponse(.success(dailyChallenges)):
      state.dailyChallenges = dailyChallenges
      return .none

    case .delayedOnAppear:
      state.isViewEnabled = true
      return .none

    case .delayedShowUpgradeInterstitial:
      state.upgradeInterstitial = .init()
      return .none

    case .delegate(.close):
      return .none

    case .delegate:
      return .none

    case let .gameButtonTapped(gameMode):
      switch state.completedGame.gameContext {
      case .dailyChallenge:
        state.gameModeIsLoading = gameMode  // TODO: Move below guard?
        guard
          let challenge = state.dailyChallenges
            .first(where: { $0.dailyChallenge.gameMode == gameMode })
        else { return .none }
        return .task {
          await .startDailyChallengeResponse(
            TaskResult {
              try await startDailyChallengeAsync(
                challenge,
                apiClient: environment.apiClient,
                date: { environment.mainRunLoop.now.date },
                fileClient: environment.fileClient
              )
            }
          )
        }

      case .shared:
        return .none
      case .solo:
        return Effect(value: .delegate(.startSoloGame(gameMode)))
      case .turnBased:
        return .none
      }

    case .onAppear:
      guard state.isDemo || state.completedGame.currentScore > 0
      else { return .task { .delegate(.close) }.animation() }

      return .run { [completedGame = state.completedGame, isDemo = state.isDemo] send in
        await environment.audioPlayer.playAsync(.transitionIn)
        await environment.audioPlayer.loopAsync(.gameOverMusicLoop)

        await withThrowingTaskGroup(of: Void.self) { group in
          group.addTask {
            await send(
              .submitGameResponse(
                TaskResult {
                  if isDemo {
                    return try await .solo(
                      environment.apiClient.requestAsync(
                        route: .demo(
                          .submitGame(
                            .init(
                              gameMode: completedGame.gameMode,
                              score: completedGame.currentScore
                            )
                          )
                        ),
                        as: LeaderboardScoreResult.self
                      )
                    )
                  } else if let request = ServerRoute.Api.Route.Games.SubmitRequest(
                    completedGame: completedGame
                  ) {
                    return try await environment.apiClient.apiRequestAsync(
                      route: .games(.submit(request)),
                      as: SubmitGameResponse.self
                    )
                  } else {
                    throw CancellationError()
                  }
                }
              ),
              animation: .default
            )
          }

          group.addTask {
            try await environment.mainRunLoop.sleep(for: .seconds(1))
            async let playedGamesCount = environment.database
              .playedGamesCountAsync(.init(gameContext: completedGame.gameContext))
            async let isFullGamePurchased =
              environment.apiClient
              .currentPlayerAsync()?.appleReceipt != nil
            guard
              try await shouldShowInterstitial(
                gamePlayedCount: playedGamesCount,
                gameContext: .init(gameContext: completedGame.gameContext),
                serverConfig: environment.serverConfig.config()
              )
            else { return }
            await send(.delayedShowUpgradeInterstitial, animation: .easeIn)
          }

          group.addTask {
            try await environment.mainRunLoop.sleep(for: .seconds(2))
            await send(.delayedOnAppear)
          }

          group.addTask {
            await send(
              .userNotificationSettingsResponse(
                environment.userNotifications.getNotificationSettingsAsync()
              )
            )
          }
        }
      }

    case .notificationsAuthAlert(.delegate(.close)):
      state.notificationsAuthAlert = nil
      return .run { send in
        await send(.delegate(.close), animation: .default)
        try? await environment.requestReviewAsync()
      }

    case .notificationsAuthAlert(.delegate(.didChooseNotificationSettings)):
      return .task { .delegate(.close) }.animation()

    case .notificationsAuthAlert:
      return .none

    case .rematchButtonTapped:
      return .none

    case .showConfetti:
      return .none

    case .startDailyChallengeResponse(.failure):
      state.gameModeIsLoading = nil
      return .none

    case let .startDailyChallengeResponse(.success(inProgressGame)):
      state.gameModeIsLoading = nil
      return .init(value: .delegate(.startGame(inProgressGame)))

    case let .submitGameResponse(.success(.dailyChallenge(result))):
      state.summary = .dailyChallenge(result)

      return .task {
        await .dailyChallengeResponse(
          TaskResult {
            try await environment.apiClient.apiRequestAsync(
              route: .dailyChallenge(.today(language: .en)),
              as: [FetchTodaysDailyChallengeResponse].self
            )
          }
        )
      }
      .animation()

    case let .submitGameResponse(.success(.shared(result))):
      return .none

    case let .submitGameResponse(.success(.solo(result))):
      state.summary = .leaderboard(
        Dictionary(
          result.ranks.compactMap { key, value in
            TimeScope(rawValue: key).map { ($0, value) }
          },
          uniquingKeysWith: { $1 }
        )
      )
      return .none
    //      return result.ranks.values.contains(where: { $0.rank <= 10 })
    //        ? showConfetti
    //        : .none

    case .submitGameResponse(.success(.turnBased)):
      return .none

    case .submitGameResponse(.failure):
      return .none

    case .upgradeInterstitial(.delegate(.close)),
      .upgradeInterstitial(.delegate(.fullGamePurchased)):
      state.upgradeInterstitial = nil
      return .none

    case .upgradeInterstitial:
      return .none

    case let .userNotificationSettingsResponse(settings):
      state.userNotificationSettings = settings
      return .none
    }
  }
)

public struct GameOverView: View {
  @Environment(\.adaptiveSize) var adaptiveSize
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.opponentImage) var defaultOpponentImage
  @Environment(\.yourImage) var defaultYourImage
  let store: Store<GameOverState, GameOverAction>
  @ObservedObject var viewStore: ViewStore<ViewState, GameOverAction>
  @State var yourImage: UIImage?
  @State var yourOpponentImage: UIImage?
  @State var isSharePresented = false

  struct ViewState: Equatable {
    let completedMatch: CompletedMatch?
    let gameContext: CompletedGame.GameContext
    let gameMode: GameMode
    let gameModeIsLoading: GameMode?
    let isDemo: Bool
    let isUpgradeInterstitialPresented: Bool
    let isViewEnabled: Bool
    let showConfetti: Bool
    let summary: GameOverState.RankSummary?
    let unplayedDaily: GameMode?
    let words: [PlayedWord]
    let you: ComposableGameCenter.Player?
    let yourOpponent: ComposableGameCenter.Player?
    let yourScore: Int
    var theirWords: [PlayedWord] { self.words.filter { !$0.isYourWord } }
    var yourWords: [PlayedWord] { self.words.filter { $0.isYourWord } }

    init(state: GameOverState) {
      self.gameContext = state.completedGame.gameContext
      self.gameMode = state.completedGame.gameMode
      let yourWords = state.completedGame.words(
        forPlayerIndex: state.completedGame.localPlayerIndex)
      self.gameModeIsLoading = state.gameModeIsLoading
      let yourScore = yourWords.reduce(into: 0) { $0 += $1.score }
      switch state.completedGame.gameContext {
      case .dailyChallenge:
        self.completedMatch = nil
      case .shared:
        self.completedMatch = nil
      case .solo:
        self.completedMatch = nil
      case .turnBased:
        self.completedMatch = state.turnBasedContext.flatMap {
          CompletedMatch(completedGame: state.completedGame, turnBasedContext: $0)
        }
      }
      self.isDemo = state.isDemo
      self.isUpgradeInterstitialPresented = state.upgradeInterstitial != nil
      self.isViewEnabled = state.isViewEnabled
      self.showConfetti = state.showConfetti
      self.summary = state.summary
      self.unplayedDaily =
        state.dailyChallenges
        .first(where: { $0.yourResult.rank == nil })?.dailyChallenge.gameMode
      self.words = state.completedGame.moves.compactMap { move -> PlayedWord? in
        guard case let .playedWord(faces) = move.type else { return nil }
        return PlayedWord(
          isYourWord: move.playerIndex == state.completedGame.localPlayerIndex,
          reactions: move.reactions,
          score: move.score,
          word: state.completedGame.cubes.string(from: faces)
        )
      }
      self.you = state.turnBasedContext?.localPlayer.player
      self.yourOpponent = state.turnBasedContext?.otherPlayer
      self.yourScore = yourScore
    }
  }

  public init(store: Store<GameOverState, GameOverAction>) {
    self.store = store
    self.viewStore = ViewStore(self.store.scope(state: ViewState.init(state:)))
  }

  public var body: some View {
    ZStack(alignment: .topTrailing) {
      ScrollView(showsIndicators: false) {
        VStack(spacing: self.adaptiveSize.pad(24)) {
          HStack {
            Image(systemName: "cube.fill")

            if !self.viewStore.isDemo {
              Spacer()
              Button(action: { self.viewStore.send(.closeButtonTapped, animation: .default) }) {
                Image(systemName: "xmark")
              }
            }
          }
          .font(.system(size: 24))
          .adaptivePadding()

          switch self.viewStore.gameContext {
          case .dailyChallenge:
            self.dailyChallengeResults
          case .shared:
            EmptyView()
          case .solo:
            self.soloResults
          case .turnBased:
            self.turnBasedResults
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(self.viewStore.isUpgradeInterstitialPresented ? 0 : 1)

        VStack(spacing: .grid(8)) {
          Divider()

          Text("Enjoying\nthe game?")
            .adaptiveFont(.matter, size: 34)
            .multilineTextAlignment(.center)

          Button(action: { self.isSharePresented.toggle() }) {
            Text("Share with a friend")
          }
          .buttonStyle(
            ActionButtonStyle(
              backgroundColor: self.colorScheme == .dark ? self.color : .isowordsBlack,
              foregroundColor: self.colorScheme == .dark ? .isowordsBlack : self.color
            )
          )
          .padding([.bottom], .grid(self.viewStore.isDemo ? 30 : 0))
        }
        .padding([.vertical], .grid(12))

      }

      IfLetStore(
        self.store.scope(
          state: \.upgradeInterstitial,
          action: GameOverAction.upgradeInterstitial
        ),
        then: { store in
          UpgradeInterstitialView(store: store)
            .transition(.opacity)
        }
      )
    }
    .foregroundColor(self.colorScheme == .dark ? self.color : .isowordsBlack)
    .background(
      (self.colorScheme == .dark ? .isowordsBlack : self.color)
        .ignoresSafeArea()
    )
    .onAppear { self.viewStore.send(.onAppear) }
    .notificationsAlert(
      store: self.store.scope(
        state: \.notificationsAuthAlert,
        action: GameOverAction.notificationsAuthAlert
      )
    )
    .sheet(isPresented: self.$isSharePresented) {
      ActivityView(activityItems: [URL(string: "https://www.isowords.xyz")!])
        .ignoresSafeArea()
    }
    .disabled(!self.viewStore.isViewEnabled)
  }

  @ViewBuilder
  var dailyChallengeResults: some View {
    let result = (/GameOverState.RankSummary.dailyChallenge)
      .extract(from: self.viewStore.summary)

    VStack(spacing: -8) {
      result.map {
        Text("\(($0.rank ?? 0) as NSNumber, formatter: ordinalFormatter) place.").fontWeight(
          .medium)
          + Text("\n")
          + Text(praise(rank: $0.rank ?? 0, outOf: $0.outOf))
      }
        ?? Text("Loading your rank!")
    }
    .animation(nil)
    .adaptiveFont(.matter, size: 52)
    .adaptivePadding([.leading, .trailing])
    .minimumScaleFactor(0.01)
    .lineLimit(2)
    .multilineTextAlignment(.center)
    .redacted(reason: result == nil ? .placeholder : [])
    .overlay(
      self.viewStore.showConfetti
        ? Confetti(
          foregroundColor: self.colorScheme == .dark ? self.color : .isowordsBlack
        )
        : nil,
      alignment: .top
    )

    VStack(spacing: 48) {
      VStack(spacing: self.adaptiveSize.pad(8)) {
        Text("Your stats")
          .frame(maxWidth: .infinity, alignment: .leading)

        Divider()
          .background((self.colorScheme == .dark ? self.color : .isowordsBlack).opacity(0.2))

        HStack {
          Text("Rank")
          Spacer()
          Text(
            "\((result?.rank ?? 0) as NSNumber, formatter: ordinalFormatter) of \(result?.outOf ?? 0)"
          )
          .redacted(reason: result == nil ? .placeholder : [])
        }
        HStack {
          Text("Score")
          Spacer()
          Text("\(self.viewStore.yourScore)")
        }
        HStack {
          Text("Words found")
          Spacer()
          Text("\(self.viewStore.yourWords.count)")
        }
      }
      .adaptivePadding([.leading, .trailing])
      .animation(nil)

      self.wordList

      if let unplayedDaily = self.viewStore.unplayedDaily {
        VStack(spacing: self.adaptiveSize.pad(8)) {
          LazyVGrid(
            columns: [
              GridItem(.flexible(), spacing: .grid(4)),
              GridItem(.flexible()),
            ]
          ) {
            GameButton(
              title: Text("Timed"),
              icon: Image(systemName: "clock.fill"),
              color: self.color,
              inactiveText: unplayedDaily == .unlimited ? Text("Played") : nil,
              isLoading: self.viewStore.gameModeIsLoading == .timed,
              resumeText: nil,
              action: { self.viewStore.send(.gameButtonTapped(.timed), animation: .default) }
            )
            .disabled(self.viewStore.gameModeIsLoading != nil)

            GameButton(
              title: Text("Unlimited"),
              icon: Image(systemName: "infinity"),
              color: self.color,
              inactiveText: unplayedDaily == .timed ? Text("Played") : nil,
              isLoading: self.viewStore.gameModeIsLoading == .unlimited,
              resumeText: nil,
              action: { self.viewStore.send(.gameButtonTapped(.unlimited), animation: .default) }
            )
            .disabled(self.viewStore.gameModeIsLoading != nil)
          }
        }
        .adaptivePadding([.leading, .trailing])
      }
    }
    .adaptiveFont(.matterMedium, size: 16)
  }

  @ViewBuilder
  var soloResults: some View {
    VStack(spacing: -8) {
      Text("\(self.viewStore.yourScore).").fontWeight(.medium)
        + Text("\n")
        + Text(praise(mode: self.viewStore.gameMode, score: self.viewStore.yourScore))
    }
    .adaptiveFont(.matter, size: 52)
    .adaptivePadding([.leading, .trailing])
    .minimumScaleFactor(0.01)
    .lineLimit(2)
    .multilineTextAlignment(.center)

    VStack(spacing: 48) {
      VStack(spacing: self.adaptiveSize.pad(8)) {
        Text("Your ranks")
          .frame(maxWidth: .infinity, alignment: .leading)

        Divider()
          .background((self.colorScheme == .dark ? self.color : .isowordsBlack).opacity(0.2))

        VStack(spacing: self.adaptiveSize.pad(8)) {
          ForEach([.lastDay, .lastWeek, .allTime], id: \TimeScope.rawValue) { timeScope in
            HStack {
              Text(timeScope.displayTitle)
              Spacer()
              let rank = (/GameOverState.RankSummary.leaderboard)
                .extract(from: self.viewStore.summary)?[timeScope]
              Text(
                "\((rank?.rank ?? 0) as NSNumber, formatter: ordinalFormatter) of \(rank?.outOf ?? 0)"
              )
              .redacted(reason: rank == nil ? .placeholder : [])
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(nil)
      }
      .adaptiveFont(.matterMedium, size: 16)
      .adaptivePadding([.leading, .trailing])
      .overlay(
        self.viewStore.showConfetti
          ? Confetti(
            foregroundColor: self.colorScheme == .dark ? self.color : .isowordsBlack
          )
          : nil,
        alignment: .top
      )

      self.wordList

      if !self.viewStore.isDemo {
        VStack(spacing: self.adaptiveSize.pad(8)) {
          Text("Play again")
            .adaptiveFont(.matterMedium, size: 16)
            .adaptivePadding([.leading, .trailing])
            .frame(maxWidth: .infinity, alignment: .leading)

          LazyVGrid(
            columns: [
              GridItem(.flexible(), spacing: .grid(4)),
              GridItem(.flexible()),
            ]
          ) {
            GameButton(
              title: Text("Timed"),
              icon: Image(systemName: "clock.fill"),
              color: .solo,
              inactiveText: nil,
              isLoading: false,
              resumeText: nil,
              action: { self.viewStore.send(.gameButtonTapped(.timed), animation: .default) }
            )

            GameButton(
              title: Text("Unlimited"),
              icon: Image(systemName: "infinity"),
              color: .solo,
              inactiveText: nil,
              isLoading: false,
              resumeText: nil,
              action: { self.viewStore.send(.gameButtonTapped(.unlimited), animation: .default) }
            )
          }
          .adaptivePadding([.leading, .trailing])
        }
      }
    }
  }

  struct DividerId: Hashable {}

  @State var containerWidth: CGFloat = 0
  @State var dividerOffset: CGFloat = 0
  @State var dragOffset: CGFloat = 0

  @ViewBuilder
  var turnBasedResults: some View {
    if let completedMatch = self.viewStore.completedMatch {
      VStack(spacing: -8) {
        Text(completedMatch.description).fontWeight(.medium)
        Text(completedMatch.detailDescription)
      }
      .adaptiveFont(.matter, size: 52)
      .overlay(
        self.viewStore.showConfetti
          ? Confetti(
            foregroundColor: self.colorScheme == .dark ? self.color : .isowordsBlack
          )
          : nil,
        alignment: .bottom
      )

      if completedMatch.isTurnBased {
        Button("Rematch?") { self.viewStore.send(.rematchButtonTapped, animation: .default) }
          .adaptiveFont(.matter, size: 14)
          .buttonStyle(
            ActionButtonStyle(
              backgroundColor: self.colorScheme == .dark ? self.color : .isowordsBlack,
              foregroundColor: self.colorScheme == .dark ? .isowordsBlack : self.color
            )
          )
      }

      VStack(spacing: 0) {

        HStack(alignment: .top, spacing: -1) {
          VStack(alignment: .trailing) {
            HStack {
              VStack {
                Text("\(completedMatch.yourName)")
                  .adaptiveFont(.matterMedium, size: 14)
                  .frame(maxWidth: .infinity, alignment: .trailing)
                  .lineLimit(1)
                Text("\(self.viewStore.yourScore)")
                  .adaptiveFont(.matterMedium, size: 20)
                  .frame(maxWidth: .infinity, alignment: .trailing)
              }

              Rectangle()
                .overlay(
                  (self.yourImage ?? self.defaultYourImage).map {
                    Image(uiImage: $0)
                      .resizable()
                      .scaledToFill()
                      .transition(.opacity)
                  }
                )
                .frame(width: 44, height: 44, alignment: .center)
                .clipShape(Circle())
            }
            .frame(maxWidth: .infinity)
            .padding([.leading, .trailing], .grid(2))

            Divider()
              .frame(height: 2)
              .background((self.colorScheme == .dark ? self.color : .isowordsBlack).opacity(0.2))

            VStack(alignment: .trailing) {
              ForEach(self.viewStore.yourWords, id: \.word) { word in
                WordView(
                  backgroundColor: self.colorScheme == .dark ? self.color : .isowordsBlack,
                  foregroundColor: self.colorScheme == .dark ? .isowordsBlack : self.color,
                  word: word
                )
              }
            }
            .padding(.top, self.viewStore.words.first?.isYourWord == .some(true) ? 0 : .grid(6))
            .padding(.grid(2))
          }
          .padding([.top, .bottom])
          .frame(maxWidth: .infinity)

          Divider()
            .frame(width: 2)
            .background((self.colorScheme == .dark ? self.color : .isowordsBlack).opacity(0.2))
            .id(DividerId())

          VStack(alignment: .leading) {
            HStack {
              Rectangle()
                .overlay(
                  (self.yourOpponentImage ?? self.defaultOpponentImage).map {
                    Image(uiImage: $0)
                      .resizable()
                      .scaledToFill()
                  }
                )
                .frame(width: 44, height: 44, alignment: .center)
                .clipShape(Circle())

              VStack {
                Text("\(completedMatch.theirName)")
                  .adaptiveFont(.matterMedium, size: 14)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .lineLimit(1)
                Text("\(completedMatch.theirScore)")
                  .adaptiveFont(.matterMedium, size: 20)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
            }
            .frame(maxWidth: .infinity)
            .padding([.leading, .trailing], .grid(2))

            Divider()
              .frame(height: 2)
              .background(
                GeometryReader { dividerGeometry in
                  (self.colorScheme == .dark ? self.color : .isowordsBlack).opacity(0.2)
                    .onAppear {
                      self.dividerOffset = dividerGeometry.frame(in: .global).origin.x
                    }
                }
              )

            VStack(alignment: .leading) {
              ForEach(self.viewStore.theirWords, id: \.word) { word in
                WordView(
                  backgroundColor: self.colorScheme == .dark ? self.color : .isowordsBlack,
                  foregroundColor: self.colorScheme == .dark ? .isowordsBlack : self.color,
                  word: word
                )
              }
            }
            .padding(.top, self.viewStore.words.first?.isYourWord == .some(true) ? .grid(6) : 0)
            .padding(.grid(2))
          }
          .padding([.top, .bottom])
          .frame(maxWidth: .infinity)
        }
        .fixedSize()
        .adaptivePadding([.leading, .trailing])
        .frame(width: UIScreen.main.bounds.size.width)
        .offset(x: (containerWidth / 2) - self.dividerOffset + (self.dragOffset / 2))
        .padding([.top, .bottom])
        .gesture(
          DragGesture()
            .onChanged { self.dragOffset = $0.translation.width }
            .onEnded { _ in withAnimation(.spring()) { self.dragOffset = 0 } }
        )
      }
      .background(
        GeometryReader { geometry in
          Color.clear
            .onAppear { self.containerWidth = geometry.size.width }
        }
      )
      .onAppear {
        self.viewStore.you?.rawValue?.loadPhoto(for: .small) { image, _ in
          self.yourImage = image
        }
        self.viewStore.yourOpponent?.rawValue?.loadPhoto(for: .small) { image, _ in
          self.yourOpponentImage = image
        }
      }
    }
  }

  var color: Color {
    switch self.viewStore.gameContext {
    case .dailyChallenge:
      return .dailyChallenge
    case .shared, .solo:
      return .solo
    case .turnBased:
      return .multiplayer
    }
  }

  var wordList: some View {
    VStack(spacing: self.adaptiveSize.pad(12)) {
      Text("Your words")
        .adaptiveFont(.matterMedium, size: 16)
        .adaptivePadding([.leading, .trailing])
        .frame(maxWidth: .infinity, alignment: .leading)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack {
          ForEach(self.viewStore.yourWords, id: \.word) { word in
            WordView(
              backgroundColor: self.colorScheme == .dark ? self.color : .isowordsBlack,
              foregroundColor: self.colorScheme == .dark ? .isowordsBlack : self.color,
              word: word
            )
          }
        }
        .adaptivePadding([.leading, .trailing])
      }
    }
  }
}

private struct WordView: View {
  @Environment(\.adaptiveSize) var adaptiveSize
  let backgroundColor: Color
  let foregroundColor: Color
  let word: PlayedWord

  var body: some View {
    ZStack(alignment: .topTrailing) {
      HStack(alignment: .top, spacing: 0) {
        Text(self.word.word.capitalized)
          .adaptiveFont(.matterMedium, size: 20)
        Text("\(self.word.score)")
          .adaptiveFont(.matterMedium, size: 14)
          .offset(y: -.grid(1))
      }
      .adaptivePadding(EdgeInsets(top: 6, leading: 12, bottom: 8, trailing: 12))
      .foregroundColor(self.foregroundColor)
      .background(self.backgroundColor)
      .adaptiveCornerRadius(
        UIRectCorner.allCorners.subtracting(self.word.isYourWord ? .bottomRight : .topLeft),
        15
      )

      HStack(spacing: -15) {
        ForEach(self.reactions(for: self.word)) { reaction in
          Text(reaction.rawValue)
            .font(.system(size: 20 + self.adaptiveSize.padding))
            .rotationEffect(.degrees(10))
        }
      }
      .offset(x: 8, y: -8)
    }
    .frame(maxWidth: .infinity, alignment: self.word.isYourWord ? .trailing : .leading)
    .padding([.leading, .trailing], .grid(1))
    .fixedSize()
  }

  func reactions(for playedWord: PlayedWord) -> [Move.Reaction] {
    (playedWord.reactions ?? [:])
      .sorted(by: { $0.key < $1.key })
      .map(\.value)
  }
}

private let ordinalFormatter: NumberFormatter = {
  let formatter = NumberFormatter()
  formatter.numberStyle = .ordinal
  return formatter
}()

extension CompletedMatch {
  fileprivate var description: String {
    switch (self.yourOutcome, self.theirOutcome) {
    case (.won, _), (_, .quit): return "You won!"
    case (.lost, _), (.quit, _): return "You lost."
    case (.tied, .tied): return "It’s a tie!"
    default: return "Game over"
    }
  }

  fileprivate var detailDescription: String {
    switch (self.yourOutcome, self.theirOutcome) {
    case (.won, _), (_, .quit): return "Nice."
    case (.lost, _), (.quit, _): return "Shucks."
    case (.tied, .tied): return "Do-over!"
    default: return "Game over"
    }
  }
}

extension GameOverEnvironment {
  func requestReviewAsync() async throws {
    let stats = try await self.database.fetchStatsAsync()
    let hasRequestedReviewBefore =
      self.userDefaults
      .doubleForKey(lastReviewRequestTimeIntervalKey) != 0
    let timeSinceLastReviewRequest =
      self.mainRunLoop.now.date.timeIntervalSince1970
      - self.userDefaults.doubleForKey(lastReviewRequestTimeIntervalKey)
    let weekInSeconds: Double = 60 * 60 * 24 * 7

    if stats.gamesPlayed >= 3
      && (!hasRequestedReviewBefore || timeSinceLastReviewRequest >= weekInSeconds)
    {
      await self.storeKit.requestReviewAsync()
      await self.userDefaults.setDoubleAsync(
        self.mainRunLoop.now.date.timeIntervalSince1970,
        lastReviewRequestTimeIntervalKey
      )
    }
  }
}

extension UpgradeInterstitialFeature.GameContext {
  init(gameContext: CompletedGame.GameContext) {
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

extension LocalDatabaseClient.GameContext {
  fileprivate init(gameContext: CompletedGame.GameContext) {
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

private func praise(rank: Int, outOf: Int) -> LocalizedStringKey {
  switch (rank, Double(rank) / Double(outOf)) {
  case (1, _):
    return "Numero uno!"
  case (2, _):
    return "Silver!"
  case (3, _):
    return "Bronze!"
  case (...10, _):
    return "Top ten!"
  case (_, ..<0.001):
    return "Amazing!"
  case (_, ..<0.01):
    return "Great job!"
  case (_, ..<0.10):
    return "Not bad!"
  case (_, ..<0.50):
    return "Keep it up!"
  default:
    return "You can do it!"
  }
}

private func praise(mode: GameMode, score: Int) -> LocalizedStringKey {
  switch (score, mode) {
  case (0, _):
    return "You there?"
  case (..<250, _):
    return "You can do it!"
  case (..<500, .timed), (..<1_000, .unlimited):
    return "Keep it up!"
  case (..<1_000, .timed), (..<3_000, .unlimited):
    return "Not bad!"
  case (..<2_000, .timed), (..<5_000, .unlimited):
    return "Great job!"
  case (..<3_000, .timed), (..<7_000, .unlimited):
    return "Amazing!"
  case (..<4_000, .timed), (..<9_000, .unlimited):
    return "Outstanding!"
  case (4_000..., .timed), (9_000..., .unlimited):
    return "Unbelievable!"
  default:
    return "Nice job!"
  }
}

private let lastReviewRequestTimeIntervalKey = "last-review-request-timeinterval"

#if DEBUG
  struct GameOverView_Solo_Previews: PreviewProvider {
    static var previews: some View {
      GameOverView(
        store: Store(
          initialState: GameOverState(
            completedGame: .solo,
            isDemo: false,
            summary: .leaderboard([
              .lastDay: .init(outOf: 100, rank: 1),
              .lastWeek: .init(outOf: 1000, rank: 10),
              .allTime: .init(outOf: 10000, rank: 100),
            ])
          ),
          reducer: gameOverReducer,
          environment: .preview
        )
      )
      .background(Color.white)
    }
  }

  struct GameOverView_DailyChallenge_Previews: PreviewProvider {
    static var previews: some View {
      GameOverView(
        store: Store(
          initialState: GameOverState(
            completedGame: .fetchedResponse,
            isDemo: false,
            summary: .dailyChallenge(
              .init(
                outOf: 1000,
                rank: 10,
                score: 1000
              )
            )
          ),
          reducer: gameOverReducer,
          environment: .preview
        )
      )
      .background(Color.white)
    }
  }

  struct GameOverView_TurnBasedGame_Previews: PreviewProvider {
    static var previews: some View {
      GameOverView(
        store: Store(
          initialState: GameOverState(
            completedGame: .turnBased,
            isDemo: false,
            summary: nil,
            turnBasedContext: .init(
              localPlayer: .mock,
              match: update(.mock) {
                $0.participants = [
                  update(.local) { $0.matchOutcome = .won },
                  update(.remote) { $0.matchOutcome = .lost },
                ]
              },
              metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
            )
          ),
          reducer: gameOverReducer,
          environment: .preview
        )
      )
      .background(Color.white)
    }
  }

  extension CompletedGame {
    public static let solo = Self(
      cubes: update(.mock) {
        $0.0.0.0 = .init(
          left: .init(letter: "A", side: .left),
          right: .init(letter: "B", side: .right),
          top: .init(letter: "C", side: .top)
        )
      },
      gameContext: .solo,
      gameMode: .timed,
      gameStartTime: Date(),
      language: .en,
      moves: .init(
        (0...10).map { _ in
          .init(
            playedAt: Date(),
            playerIndex: nil,
            reactions: nil,
            score: 10,
            type: .playedWord([
              .init(index: .zero, side: .left),
              .init(index: .zero, side: .right),
              .init(index: .zero, side: .top),
            ])
          )
        }),
      secondsPlayed: 0
    )

    public static let fetchedResponse = update(Self.solo) {
      $0.gameContext = .dailyChallenge(.init(rawValue: UUID()))
    }

    public static let turnBased = update(Self.solo) {
      $0.gameContext = .turnBased(playerIndexToId: [:])
      $0.localPlayerIndex = 0
      $0.moves = .init(
        (0...10).map { index in
          update(.playedWord(length: index.isMultiple(of: 2) ? 4 : index + 3)) {
            $0.playerIndex = .init(rawValue: index % 2)
            if index.isMultiple(of: 3) {
              $0.reactions = [
                .init(rawValue: index % 2): Move.Reaction.allCases[
                  index % Move.Reaction.allCases.count]
              ]
            }
          }
        })
    }
  }

  extension GameOverEnvironment {
    public static let preview = Self(
      apiClient: .noop,
      audioPlayer: .noop,
      database: .noop,
      fileClient: .noop,
      mainRunLoop: .immediate,
      remoteNotifications: .noop,
      serverConfig: .noop,
      storeKit: .noop,
      userDefaults: .noop,
      userNotifications: .noop
    )
  }
#endif
