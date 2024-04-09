import AudioPlayerClient
import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import ComposableUserNotifications
import DailyChallengeHelpers
import LocalDatabaseClient
import NotificationsAuthAlert
import Overture
import SharedModels
import SharedSwiftUIEnvironment
import Styleguide
import SwiftUI
import SwiftUIHelpers
import UpgradeInterstitialFeature
import UserDefaultsClient

@Reducer
public struct GameOver {
  @Reducer(state: .equatable)
  public enum Destination {
    case notificationsAuthAlert(NotificationsAuthAlert)
    case upgradeInterstitial(UpgradeInterstitial)
  }

  @ObservableState
  public struct State: Equatable {
    public var completedGame: CompletedGame
    public var dailyChallenges: [FetchTodaysDailyChallengeResponse]
    @Presents public var destination: Destination.State?
    public var gameModeIsLoading: GameMode?
    public var isDemo: Bool
    public var isNotificationMenuPresented: Bool
    public var isViewEnabled: Bool
    public var showConfetti: Bool
    public var summary: RankSummary?
    public var turnBasedContext: TurnBasedContext?
    public var userNotificationSettings: UserNotificationClient.Notification.Settings?

    var completedMatch: CompletedMatch? {
      switch self.completedGame.gameContext {
      case .dailyChallenge, .shared, .solo:
        return nil
      case .turnBased:
        return self.turnBasedContext.flatMap {
          CompletedMatch(completedGame: self.completedGame, turnBasedContext: $0)
        }
      }
    }
    var theirWords: [PlayedWord] { self.words.filter { !$0.isYourWord } }
    var unplayedDaily: GameMode? {
      self.dailyChallenges
        .first(where: { $0.yourResult.rank == nil })?.dailyChallenge.gameMode
    }
    var words: [PlayedWord] {
      self.completedGame.moves.compactMap { move in
        move.type.playedWord.map {
          PlayedWord(
            isYourWord: move.playerIndex == self.completedGame.localPlayerIndex,
            reactions: move.reactions,
            score: move.score,
            word: self.completedGame.cubes.string(from: $0)
          )
        }
      }
    }
    var you: ComposableGameCenter.Player? { self.turnBasedContext?.localPlayer.player }
    var yourOpponent: ComposableGameCenter.Player? { self.turnBasedContext?.otherPlayer }
    var yourWords: [PlayedWord] { self.words.filter { $0.isYourWord } }
    var yourScore: Int { yourWords.reduce(into: 0) { $0 += $1.score } }

    public init(
      completedGame: CompletedGame,
      dailyChallenges: [FetchTodaysDailyChallengeResponse] = [],
      destination: Destination.State? = nil,
      gameModeIsLoading: GameMode? = nil,
      isDemo: Bool,
      isNotificationMenuPresented: Bool = false,
      isViewEnabled: Bool = false,
      showConfetti: Bool = false,
      summary: RankSummary? = nil,
      turnBasedContext: TurnBasedContext? = nil,
      userNotificationSettings: UserNotificationClient.Notification.Settings? = nil
    ) {
      self.completedGame = completedGame
      self.dailyChallenges = dailyChallenges
      self.destination = destination
      self.gameModeIsLoading = gameModeIsLoading
      self.isDemo = isDemo
      self.isNotificationMenuPresented = isNotificationMenuPresented
      self.isViewEnabled = isViewEnabled
      self.showConfetti = showConfetti
      self.summary = summary
      self.turnBasedContext = turnBasedContext
      self.userNotificationSettings = userNotificationSettings
    }

    @CasePathable
    @dynamicMemberLookup
    public enum RankSummary: Equatable {
      case dailyChallenge(DailyChallengeResult)
      case leaderboard([TimeScope: LeaderboardScoreResult.Rank])
    }
  }

  public enum Action {
    case closeButtonTapped
    case dailyChallengeResponse(Result<[FetchTodaysDailyChallengeResponse], Error>)
    case delayedOnAppear
    case delayedShowUpgradeInterstitial
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case gameButtonTapped(GameMode)
    case rematchButtonTapped
    case showConfetti
    case startDailyChallengeResponse(Result<InProgressGame, Error>)
    case task
    case submitGameResponse(Result<SubmitGameResponse, Error>)
    case userNotificationSettingsResponse(UserNotificationClient.Notification.Settings)

    public enum Delegate: Equatable {
      case startGame(InProgressGame)
      case startSoloGame(GameMode)
    }
  }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.audioPlayer) var audioPlayer
  @Dependency(\.database) var database
  @Dependency(\.dismissGame) var dismissGame
  @Dependency(\.fileClient) var fileClient
  @Dependency(\.mainRunLoop) var mainRunLoop
  @Dependency(\.storeKit.requestReview) var requestReview
  @Dependency(\.serverConfig.config) var serverConfig
  @Dependency(\.userDefaults) var userDefaults
  @Dependency(\.userNotifications.getNotificationSettings) var getUserNotificationSettings

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .closeButtonTapped:
        guard
          [.notDetermined, .provisional]
            .contains(state.userNotificationSettings?.authorizationStatus),
          case .dailyChallenge = state.completedGame.gameContext
        else {
          return .run { send in
            try? await self.requestReviewAsync()
            await self.dismissGame(animation: .default)
          }
        }

        state.destination = .notificationsAuthAlert(NotificationsAuthAlert.State())
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
        state.destination = .upgradeInterstitial(UpgradeInterstitial.State())
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
          return .run { send in
            await send(
              .startDailyChallengeResponse(
                Result {
                  try await startDailyChallengeAsync(
                    challenge,
                    apiClient: self.apiClient,
                    date: { self.mainRunLoop.now.date },
                    fileClient: self.fileClient
                  )
                }
              )
            )
          }

        case .shared:
          return .none
        case .solo:
          return .send(.delegate(.startSoloGame(gameMode)))
        case .turnBased:
          return .none
        }

      case .destination(.dismiss)
      where state.destination.is(\.some.notificationsAuthAlert):
        return .run { _ in
          try? await self.requestReviewAsync()
          await self.dismissGame(animation: .default)
        }

      case .destination(
        .presented(.notificationsAuthAlert(.delegate(.didChooseNotificationSettings)))
      ):
        return .run { _ in
          await self.dismissGame(animation: .default)
        }

      case .destination:
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
        return .send(.delegate(.startGame(inProgressGame)))

      case let .submitGameResponse(.success(.dailyChallenge(result))):
        state.summary = .dailyChallenge(result)

        return .run { send in
          await send(
            .dailyChallengeResponse(
              Result {
                try await self.apiClient.apiRequest(
                  route: .dailyChallenge(.today(language: .en)),
                  as: [FetchTodaysDailyChallengeResponse].self
                )
              }
            ),
            animation: .default
          )
        }

      case .submitGameResponse(.success(.shared)):
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

      case .submitGameResponse(.success(.turnBased)):
        return .none

      case .submitGameResponse(.failure):
        return .none

      case .task:
        return .run { [completedGame = state.completedGame, isDemo = state.isDemo] send in
          guard isDemo || completedGame.currentScore > 0
          else {
            await self.dismissGame(animation: .default)
            return
          }

          await self.audioPlayer.play(.transitionIn)
          await self.audioPlayer.loop(.gameOverMusicLoop)

          await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
              if isDemo {
                let request = ServerRoute.Demo.SubmitRequest(
                  gameMode: completedGame.gameMode,
                  score: completedGame.currentScore
                )
                await send(
                  .submitGameResponse(
                    Result {
                      try await .solo(
                        self.apiClient.request(
                          route: .demo(.submitGame(request)),
                          as: LeaderboardScoreResult.self
                        )
                      )
                    }
                  ),
                  animation: .default
                )
              } else if let request = ServerRoute.Api.Route.Games.SubmitRequest(
                completedGame: completedGame
              ) {
                await send(
                  .submitGameResponse(
                    Result {
                      try await self.apiClient.apiRequest(
                        route: .games(.submit(request)),
                        as: SubmitGameResponse.self
                      )
                    }
                  ),
                  animation: .default
                )
              }
            }

            group.addTask {
              try await self.mainRunLoop.sleep(for: .seconds(1))
              let playedGamesCount = try await self.database
                .playedGamesCount(.init(gameContext: completedGame.gameContext))
              let isFullGamePurchased =
                self.apiClient.currentPlayer()?.appleReceipt != nil
              guard
                !isFullGamePurchased,
                shouldShowInterstitial(
                  gamePlayedCount: playedGamesCount,
                  gameContext: .init(gameContext: completedGame.gameContext),
                  serverConfig: self.serverConfig()
                )
              else { return }
              await send(.delayedShowUpgradeInterstitial, animation: .easeIn)
            }

            group.addTask {
              try await self.mainRunLoop.sleep(for: .seconds(2))
              await send(.delayedOnAppear)
            }

            group.addTask {
              await send(
                .userNotificationSettingsResponse(
                  getUserNotificationSettings()
                )
              )
            }
          }
        }

      case let .userNotificationSettingsResponse(settings):
        state.userNotificationSettings = settings
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination) {
      Destination.body
    }
  }

  private func requestReviewAsync() async throws {
    let stats = try await self.database.fetchStats()
    let hasRequestedReviewBefore =
      self.userDefaults.doubleForKey(lastReviewRequestTimeIntervalKey) != 0
    let timeSinceLastReviewRequest =
      self.mainRunLoop.now.date.timeIntervalSince1970
      - self.userDefaults.doubleForKey(lastReviewRequestTimeIntervalKey)
    let weekInSeconds: Double = 60 * 60 * 24 * 7

    if stats.gamesPlayed >= 3
      && (!hasRequestedReviewBefore || timeSinceLastReviewRequest >= weekInSeconds)
    {
      await self.requestReview()
      await self.userDefaults.setDouble(
        self.mainRunLoop.now.date.timeIntervalSince1970,
        lastReviewRequestTimeIntervalKey
      )
    }
  }
}

public struct GameOverView: View {
  @Environment(\.adaptiveSize) var adaptiveSize
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.opponentImage) var defaultOpponentImage
  @Environment(\.yourImage) var defaultYourImage
  @Bindable var store: StoreOf<GameOver>
  @State var yourImage: UIImage?
  @State var yourOpponentImage: UIImage?
  @State var isSharePresented = false

  public init(store: StoreOf<GameOver>) {
    self.store = store
  }

  public var body: some View {
    ZStack(alignment: .topTrailing) {
      ScrollView(showsIndicators: false) {
        VStack(spacing: self.adaptiveSize.pad(24)) {
          HStack {
            Image(systemName: "cube.fill")

            if !store.isDemo {
              Spacer()
              Button {
                store.send(.closeButtonTapped, animation: .default)
              } label: {
                Image(systemName: "xmark")
              }
            }
          }
          .font(.system(size: 24))
          .adaptivePadding()

          switch store.completedGame.gameContext {
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
        .opacity(store.destination.is(\.some.upgradeInterstitial) ? 0 : 1)

        VStack(spacing: .grid(8)) {
          Divider()

          Text("Enjoying\nthe game?")
            .adaptiveFont(.matter, size: 34)
            .multilineTextAlignment(.center)

          Button {
            self.isSharePresented.toggle()
          } label: {
            Text("Share with a friend")
          }
          .buttonStyle(
            ActionButtonStyle(
              backgroundColor: self.colorScheme == .dark ? self.color : .isowordsBlack,
              foregroundColor: self.colorScheme == .dark ? .isowordsBlack : self.color
            )
          )
          .padding(.bottom, .grid(store.isDemo ? 30 : 0))
        }
        .padding(.vertical, .grid(12))
      }

      if let store = store.scope(
        state: \.destination?.upgradeInterstitial,
        action: \.destination.upgradeInterstitial.presented
      ) {
        UpgradeInterstitialView(store: store)
          .transition(.opacity)
      }
    }
    .foregroundColor(self.colorScheme == .dark ? self.color : .isowordsBlack)
    .background(
      (self.colorScheme == .dark ? .isowordsBlack : self.color)
        .ignoresSafeArea()
    )
    .task { await store.send(.task).finish() }
    .notificationsAlert(
      $store.scope(
        state: \.destination?.notificationsAuthAlert,
        action: \.destination.notificationsAuthAlert
      )
    )
    .sheet(isPresented: self.$isSharePresented) {
      ActivityView(activityItems: [URL(string: "https://www.isowords.xyz")!])
        .ignoresSafeArea()
    }
    .disabled(!store.isViewEnabled)
  }

  @ViewBuilder
  var dailyChallengeResults: some View {
    let result = store.summary?.dailyChallenge

    VStack(spacing: -8) {
      result.map {
        Text("\(($0.rank ?? 0) as NSNumber, formatter: ordinalFormatter) place.").fontWeight(
          .medium)
          + Text("\n")
          + Text(praise(rank: $0.rank ?? 0, outOf: $0.outOf))
      }
        ?? Text("Loading your rank!")
    }
    .animation(.default, value: result)
    .adaptiveFont(.matter, size: 52)
    .adaptivePadding(.horizontal)
    .minimumScaleFactor(0.01)
    .lineLimit(2)
    .multilineTextAlignment(.center)
    .redacted(reason: result == nil ? .placeholder : [])
    .overlay(alignment: .top) {
      if store.showConfetti {
        Confetti(foregroundColor: self.colorScheme == .dark ? self.color : .isowordsBlack)
      }
    }

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
          Text("\(store.yourScore)")
        }
        HStack {
          Text("Words found")
          Spacer()
          Text("\(store.yourWords.count)")
        }
      }
      .adaptivePadding(.horizontal)
      .animation(.default, value: result)

      self.wordList

      if let unplayedDaily = store.unplayedDaily {
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
              isLoading: store.gameModeIsLoading == .timed,
              resumeText: nil,
              action: { store.send(.gameButtonTapped(.timed), animation: .default) }
            )
            .disabled(store.gameModeIsLoading != nil)

            GameButton(
              title: Text("Unlimited"),
              icon: Image(systemName: "infinity"),
              color: self.color,
              inactiveText: unplayedDaily == .timed ? Text("Played") : nil,
              isLoading: store.gameModeIsLoading == .unlimited,
              resumeText: nil,
              action: { store.send(.gameButtonTapped(.unlimited), animation: .default) }
            )
            .disabled(store.gameModeIsLoading != nil)
          }
        }
        .adaptivePadding(.horizontal)
      }
    }
    .adaptiveFont(.matterMedium, size: 16)
  }

  @ViewBuilder
  var soloResults: some View {
    VStack(spacing: -8) {
      Text("\(store.yourScore).").fontWeight(.medium)
        + Text("\n")
      + Text(praise(mode: store.completedGame.gameMode, score: store.yourScore))
    }
    .adaptiveFont(.matter, size: 52)
    .adaptivePadding(.horizontal)
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
              let rank = store.summary?.leaderboard?[timeScope]
              Text(
                """
                \((rank?.rank ?? 0) as NSNumber, formatter: ordinalFormatter) of \
                \(rank?.outOf ?? 0)
                """
              )
              .redacted(reason: rank == nil ? .placeholder : [])
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.default, value: store.summary)
      }
      .adaptiveFont(.matterMedium, size: 16)
      .adaptivePadding(.horizontal)
      .overlay(alignment: .top) {
        if store.showConfetti {
          Confetti(foregroundColor: self.colorScheme == .dark ? self.color : .isowordsBlack)
        }
      }

      self.wordList

      if !store.isDemo {
        VStack(spacing: self.adaptiveSize.pad(8)) {
          Text("Play again")
            .adaptiveFont(.matterMedium, size: 16)
            .adaptivePadding(.horizontal)
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
              action: { store.send(.gameButtonTapped(.timed), animation: .default) }
            )

            GameButton(
              title: Text("Unlimited"),
              icon: Image(systemName: "infinity"),
              color: .solo,
              inactiveText: nil,
              isLoading: false,
              resumeText: nil,
              action: { store.send(.gameButtonTapped(.unlimited), animation: .default) }
            )
          }
          .adaptivePadding(.horizontal)
        }
      }
    }
  }

  struct DividerID: Hashable {}

  @State var containerWidth: CGFloat = 0
  @State var dividerOffset: CGFloat = 0
  @State var dragOffset: CGFloat = 0

  @ViewBuilder
  var turnBasedResults: some View {
    if let completedMatch = store.completedMatch {
      VStack(spacing: -8) {
        Text(completedMatch.description).fontWeight(.medium)
        Text(completedMatch.detailDescription)
      }
      .adaptiveFont(.matter, size: 52)
      .overlay(alignment: .bottom) {
        if store.showConfetti {
          Confetti(foregroundColor: self.colorScheme == .dark ? self.color : .isowordsBlack)
        }
      }

      if completedMatch.isTurnBased {
        Button("Rematch?") { store.send(.rematchButtonTapped, animation: .default) }
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
                Text("\(store.yourScore)")
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
            .padding(.horizontal, .grid(2))

            Divider()
              .frame(height: 2)
              .background((self.colorScheme == .dark ? self.color : .isowordsBlack).opacity(0.2))

            VStack(alignment: .trailing) {
              ForEach(store.yourWords, id: \.word) { word in
                WordView(
                  backgroundColor: self.colorScheme == .dark ? self.color : .isowordsBlack,
                  foregroundColor: self.colorScheme == .dark ? .isowordsBlack : self.color,
                  word: word
                )
              }
            }
            .padding(.top, store.words.first?.isYourWord == .some(true) ? 0 : .grid(6))
            .padding(.grid(2))
          }
          .padding(.vertical)
          .frame(maxWidth: .infinity)

          Divider()
            .frame(width: 2)
            .background((self.colorScheme == .dark ? self.color : .isowordsBlack).opacity(0.2))
            .id(DividerID())

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
            .padding(.horizontal, .grid(2))

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
              ForEach(store.theirWords, id: \.word) { word in
                WordView(
                  backgroundColor: self.colorScheme == .dark ? self.color : .isowordsBlack,
                  foregroundColor: self.colorScheme == .dark ? .isowordsBlack : self.color,
                  word: word
                )
              }
            }
            .padding(.top, store.words.first?.isYourWord == .some(true) ? .grid(6) : 0)
            .padding(.grid(2))
          }
          .padding(.vertical)
          .frame(maxWidth: .infinity)
        }
        .fixedSize()
        .adaptivePadding(.horizontal)
        .frame(width: UIScreen.main.bounds.size.width)
        .offset(x: (containerWidth / 2) - self.dividerOffset + (self.dragOffset / 2))
        .padding(.vertical)
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
        store.you?.rawValue?.loadPhoto(for: .small) { image, _ in
          self.yourImage = image
        }
        store.yourOpponent?.rawValue?.loadPhoto(for: .small) { image, _ in
          self.yourOpponentImage = image
        }
      }
    }
  }

  var color: Color {
    switch store.completedGame.gameContext {
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
        .adaptivePadding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack {
          ForEach(store.yourWords, id: \.word) { word in
            WordView(
              backgroundColor: self.colorScheme == .dark ? self.color : .isowordsBlack,
              foregroundColor: self.colorScheme == .dark ? .isowordsBlack : self.color,
              word: word
            )
          }
        }
        .adaptivePadding(.horizontal)
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
    .padding(.horizontal, .grid(1))
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
          initialState: GameOver.State(
            completedGame: .solo,
            isDemo: false,
            summary: .leaderboard([
              .lastDay: .init(outOf: 100, rank: 1),
              .lastWeek: .init(outOf: 1000, rank: 10),
              .allTime: .init(outOf: 10000, rank: 100),
            ])
          )
        ) {
          GameOver()
        }
      )
      .background(Color.white)
    }
  }

  struct GameOverView_DailyChallenge_Previews: PreviewProvider {
    static var previews: some View {
      GameOverView(
        store: Store(
          initialState: GameOver.State(
            completedGame: .fetchedResponse,
            isDemo: false,
            summary: .dailyChallenge(
              .init(
                outOf: 1000,
                rank: 10,
                score: 1000
              )
            )
          )
        ) {
          GameOver()
        }
      )
      .background(Color.white)
    }
  }

  struct GameOverView_TurnBasedGame_Previews: PreviewProvider {
    static var previews: some View {
      GameOverView(
        store: Store(
          initialState: GameOver.State(
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
          )
        ) {
          GameOver()
        }
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
#endif
