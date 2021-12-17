import ApiClient
import ClientModels
import ComposableArchitecture
import ComposableUserNotifications
import DailyChallengeHelpers
import DateHelpers
import FileClient
import NotificationHelpers
import NotificationsAuthAlert
import Overture
import RemoteNotificationsClient
import SharedModels
import Styleguide
import SwiftUI

public struct DailyChallengeState: Equatable {
  public var alert: AlertState<DailyChallengeAction.AlertAction>?
  public var dailyChallenges: [FetchTodaysDailyChallengeResponse]
  public var gameModeIsLoading: GameMode?
  public var inProgressDailyChallengeUnlimited: InProgressGame?
  public var route: Route?
  public var notificationsAuthAlert: NotificationsAuthAlertState?
  public var userNotificationSettings: UserNotificationClient.Notification.Settings?

  public enum Route: Equatable {
    case results(DailyChallengeResultsState)

    public enum Tag: Int {
      case results
    }

    var tag: Tag {
      switch self {
      case .results:
        return .results
      }
    }
  }

  public init(
    alert: AlertState<DailyChallengeAction.AlertAction>? = nil,
    dailyChallenges: [FetchTodaysDailyChallengeResponse] = [],
    gameModeIsLoading: GameMode? = nil,
    inProgressDailyChallengeUnlimited: InProgressGame? = nil,
    route: Route? = nil,
    notificationsAuthAlert: NotificationsAuthAlertState? = nil,
    userNotificationSettings: UserNotificationClient.Notification.Settings? = nil
  ) {
    self.alert = alert
    self.dailyChallenges = dailyChallenges
    self.gameModeIsLoading = gameModeIsLoading
    self.inProgressDailyChallengeUnlimited = inProgressDailyChallengeUnlimited
    self.route = route
    self.notificationsAuthAlert = notificationsAuthAlert
    self.userNotificationSettings = userNotificationSettings
  }
}

public enum DailyChallengeAction {
  case alert(AlertAction)
  case dailyChallengeResults(DailyChallengeResultsAction)
  case delegate(DelegateAction)
  case fetchTodaysDailyChallengeResponse(Result<[FetchTodaysDailyChallengeResponse], ApiError>)
  case gameButtonTapped(GameMode)
  case onAppear
  case notificationButtonTapped
  case notificationsAuthAlert(NotificationsAuthAlertAction)
  case setNavigation(tag: DailyChallengeState.Route.Tag?)
  case startDailyChallengeResponse(Result<InProgressGame, DailyChallengeError>)
  case userNotificationSettingsResponse(UserNotificationClient.Notification.Settings)

  public enum AlertAction {
    case dismiss
  }

  public enum DelegateAction {
    case startGame(InProgressGame)
  }
}

public struct DailyChallengeEnvironment {
  var apiClient: ApiClient
  var fileClient: FileClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var mainRunLoop: AnySchedulerOf<RunLoop>
  var remoteNotifications: RemoteNotificationsClient
  var userNotifications: UserNotificationClient

  public init(
    apiClient: ApiClient,
    fileClient: FileClient,
    mainQueue: AnySchedulerOf<DispatchQueue>,
    mainRunLoop: AnySchedulerOf<RunLoop>,
    remoteNotifications: RemoteNotificationsClient,
    userNotifications: UserNotificationClient
  ) {
    self.apiClient = apiClient
    self.fileClient = fileClient
    self.mainQueue = mainQueue
    self.mainRunLoop = mainRunLoop
    self.remoteNotifications = remoteNotifications
    self.userNotifications = userNotifications
  }
}

public let dailyChallengeReducer = Reducer<
  DailyChallengeState, DailyChallengeAction, DailyChallengeEnvironment
>.combine(
  dailyChallengeResultsReducer
    ._pullback(
      state: (\DailyChallengeState.route).appending(path: /DailyChallengeState.Route.results),
      action: /DailyChallengeAction.dailyChallengeResults,
      environment: { .init(apiClient: $0.apiClient, mainQueue: $0.mainQueue) }
    ),

  notificationsAuthAlertReducer
    .optional()
    .pullback(
      state: \.notificationsAuthAlert,
      action: /DailyChallengeAction.notificationsAuthAlert,
      environment: {
        NotificationsAuthAlertEnvironment(
          mainRunLoop: $0.mainRunLoop,
          remoteNotifications: $0.remoteNotifications,
          userNotifications: $0.userNotifications
        )
      }
    ),

  .init { state, action, environment in
    switch action {
    case .alert(.dismiss):
      state.alert = nil
      return .none

    case .dailyChallengeResults:
      return .none

    case .delegate:
      return .none

    case .fetchTodaysDailyChallengeResponse(.failure):
      return .none

    case let .fetchTodaysDailyChallengeResponse(.success(response)):
      state.dailyChallenges = response
      return .none

    case let .gameButtonTapped(gameMode):
      guard
        let challenge = state.dailyChallenges
          .first(where: { $0.dailyChallenge.gameMode == gameMode })
      else { return .none }

      let isPlayable: Bool
      switch challenge.dailyChallenge.gameMode {
      case .timed:
        isPlayable = !challenge.yourResult.started
      case .unlimited:
        isPlayable = !challenge.yourResult.started || state.inProgressDailyChallengeUnlimited != nil
      }

      guard isPlayable
      else {
        state.alert = .alreadyPlayed(nextStartsAt: challenge.dailyChallenge.endsAt)
        return .none
      }

      state.gameModeIsLoading = challenge.dailyChallenge.gameMode

      return startDailyChallenge(
        challenge,
        apiClient: environment.apiClient,
        date: { environment.mainRunLoop.now.date },
        fileClient: environment.fileClient,
        mainRunLoop: environment.mainRunLoop
      )
      .catchToEffect(DailyChallengeAction.startDailyChallengeResponse)

    case .onAppear:
      return .merge(
        environment.apiClient.apiRequest(
          route: .dailyChallenge(.today(language: .en)),
          as: [FetchTodaysDailyChallengeResponse].self
        )
        .receive(on: environment.mainRunLoop.animation())
        .catchToEffect(DailyChallengeAction.fetchTodaysDailyChallengeResponse),

        environment.userNotifications.getNotificationSettings
          .receive(on: environment.mainRunLoop)
          .map(DailyChallengeAction.userNotificationSettingsResponse)
          .eraseToEffect()
      )

    case .notificationButtonTapped:
      state.notificationsAuthAlert = .init()
      return .none

    case .notificationsAuthAlert(.delegate(.close)):
      state.notificationsAuthAlert = nil
      return .none

    case let .notificationsAuthAlert(.delegate(.didChooseNotificationSettings(settings))):
      state.userNotificationSettings = settings
      state.notificationsAuthAlert = nil
      return .none

    case .notificationsAuthAlert:
      return .none

    case .setNavigation(tag: .results):
      state.route = .results(.init())
      return .none

    case .setNavigation(tag: .none):
      state.route = nil
      return .none

    case let .startDailyChallengeResponse(.failure(.alreadyPlayed(endsAt))):
      state.alert = .alreadyPlayed(nextStartsAt: endsAt)
      state.gameModeIsLoading = nil
      return .none

    case let .startDailyChallengeResponse(.failure(.couldNotFetch(nextStartsAt))):
      state.alert = .couldNotFetchDaily(nextStartsAt: nextStartsAt)
      state.gameModeIsLoading = nil
      return .none

    case let .startDailyChallengeResponse(.success(inProgressGame)):
      state.gameModeIsLoading = nil
      return .init(value: .delegate(.startGame(inProgressGame)))

    case let .userNotificationSettingsResponse(settings):
      state.userNotificationSettings = settings
      return .none
    }
  }
)

extension AlertState where Action == DailyChallengeAction.AlertAction {
  static func alreadyPlayed(nextStartsAt: Date) -> Self {
    Self(
      title: .init("Already played"),
      message: .init(
        """
        You already played today’s daily challenge. You can play the next one in \
        \(nextStartsAt, formatter: relativeFormatter).
        """),
      dismissButton: .default(.init("OK"), action: .send(.dismiss))
    )
  }

  static func couldNotFetchDaily(nextStartsAt: Date) -> Self {
    Self(
      title: .init("Couldn’t start today’s daily"),
      message: .init(
        """
        We’re sorry. We were unable to fetch today’s daily or you already started it \
        earlier today. You can play the next daily in \(nextStartsAt, formatter: relativeFormatter).
        """),
      dismissButton: .default(.init("OK"), action: .send(.dismiss))
    )
  }
}

public struct DailyChallengeView: View {
  @Environment(\.adaptiveSize) var adaptiveSize
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.date) var date
  let store: Store<DailyChallengeState, DailyChallengeAction>
  @ObservedObject var viewStore: ViewStore<ViewState, DailyChallengeAction>

  struct ViewState: Equatable {
    let gameModeIsLoading: GameMode?
    let isNotificationStatusDetermined: Bool
    let numberOfPlayers: Int
    let routeTag: DailyChallengeState.Route.Tag?
    let timedState: ButtonState
    let unlimitedState: ButtonState

    enum ButtonState: Equatable {
      case played(rank: Int, outOf: Int)
      case playable
      case resume(currentScore: Int)
      case unplayable
    }

    init(state: DailyChallengeState) {
      self.gameModeIsLoading = state.gameModeIsLoading
      self.isNotificationStatusDetermined = ![.notDetermined, .provisional]
        .contains(state.userNotificationSettings?.authorizationStatus)
      self.numberOfPlayers = state.dailyChallenges.numberOfPlayers
      self.routeTag = state.route?.tag
      self.timedState = .init(
        fetchedResponse: state.dailyChallenges.timed,
        inProgressGame: nil
      )
      self.unlimitedState = .init(
        fetchedResponse: state.dailyChallenges.unlimited,
        inProgressGame: state.inProgressDailyChallengeUnlimited
      )
    }
  }

  public init(store: Store<DailyChallengeState, DailyChallengeAction>) {
    self.store = store
    self.viewStore = ViewStore(self.store.scope(state: ViewState.init))
  }

  public var body: some View {
    GeometryReader { proxy in
      VStack {
        Spacer()
          .frame(maxHeight: .grid(16))

        VStack(spacing: .grid(8)) {
          Group {
            if self.viewStore.numberOfPlayers <= 1 {
              (Text("Play")
                + Text("\nagainst the")
                + Text("\ncommunity"))
            } else {
              (Text("\(self.viewStore.numberOfPlayers)")
                + Text("\npeople have")
                + Text("\nplayed!"))
            }
          }
          .font(.custom(.matterMedium, size: self.adaptiveSize.pad(48, by: 2)))
          .lineLimit(3)
          .minimumScaleFactor(0.2)
          .multilineTextAlignment(.center)

          (Text("(") + Text(timeDescriptionUntilTomorrow(now: self.date())) + Text(" left)"))
            .adaptiveFont(.matter, size: 20)
        }
        .screenEdgePadding(.horizontal)

        Spacer()

        LazyVGrid(
          columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible()),
          ]
        ) {
          GameButton(
            title: Text("Timed"),
            icon: Image(systemName: "clock.fill"),
            color: .dailyChallenge,
            inactiveText: self.viewStore.timedState.inactiveText,
            isLoading: self.viewStore.gameModeIsLoading == .timed,
            resumeText: self.viewStore.timedState.resumeText,
            action: { self.viewStore.send(.gameButtonTapped(.timed), animation: .default) }
          )
          .disabled(self.viewStore.gameModeIsLoading != nil)

          GameButton(
            title: Text("Unlimited"),
            icon: Image(systemName: "infinity"),
            color: .dailyChallenge,
            inactiveText: self.viewStore.unlimitedState.inactiveText,
            isLoading: self.viewStore.gameModeIsLoading == .unlimited,
            resumeText: self.viewStore.unlimitedState.resumeText,
            action: { self.viewStore.send(.gameButtonTapped(.unlimited), animation: .default) }
          )
          .disabled(self.viewStore.gameModeIsLoading != nil)
        }
        .adaptivePadding([.vertical])
        .screenEdgePadding(.horizontal)

        NavigationLink(
          destination: IfLetStore(
            self.store.scope(
              state: (\DailyChallengeState.route)
                .appending(path: /DailyChallengeState.Route.results)
                .extract(from:),
              action: DailyChallengeAction.dailyChallengeResults
            ),
            then: DailyChallengeResultsView.init(store:)
          ),
          tag: DailyChallengeState.Route.Tag.results,
          selection: viewStore.binding(
            get: \.routeTag,
            send: DailyChallengeAction.setNavigation(tag:)
          )
        ) {
          HStack {
            Text("View all results")
              .adaptiveFont(.matterMedium, size: 16)
            Spacer()
            Image(systemName: "arrow.right")
              .font(.system(size: self.adaptiveSize.pad(16)))
          }
          .adaptivePadding(.horizontal, .grid(5))
          .adaptivePadding(.vertical, .grid(9))
          .padding(.bottom, proxy.safeAreaInsets.bottom / 2)
        }
        .frame(maxWidth: .infinity)
        .foregroundColor((self.colorScheme == .dark ? .isowordsBlack : .dailyChallenge))
        .background(self.colorScheme == .dark ? Color.dailyChallenge : .isowordsBlack)
      }
      .onAppear { self.viewStore.send(.onAppear) }
      .alert(
        self.store.scope(state: \.alert, action: DailyChallengeAction.alert), dismiss: .dismiss
      )
      .navigationStyle(
        backgroundColor: self.colorScheme == .dark ? .isowordsBlack : .dailyChallenge,
        foregroundColor: self.colorScheme == .dark ? .dailyChallenge : .isowordsBlack,
        title: Text("Daily Challenge"),
        trailing: Group {
          if !self.viewStore.isNotificationStatusDetermined {
            ReminderBell {
              self.viewStore.send(.notificationButtonTapped, animation: .default)
            }
            .transition(
              AnyTransition
                .scale(scale: 0)
                .animation(Animation.easeOut.delay(1))
            )
          }
        }
      )
      .edgesIgnoringSafeArea(.bottom)
    }
    .notificationsAlert(
      store: self.store.scope(
        state: \.notificationsAuthAlert,
        action: DailyChallengeAction.notificationsAuthAlert
      )
    )
  }
}

extension DailyChallengeView.ViewState.ButtonState {
  init(
    fetchedResponse: FetchTodaysDailyChallengeResponse?,
    inProgressGame: InProgressGame?
  ) {
    if let rank = fetchedResponse?.yourResult.rank,
      let outOf = fetchedResponse?.yourResult.outOf
    {
      self = .played(rank: rank, outOf: outOf)
    } else if let currentScore = inProgressGame?.currentScore {
      self = .resume(currentScore: currentScore)
    } else if fetchedResponse?.yourResult.started == .some(true) {
      self = .unplayable
    } else {
      self = .playable
    }
  }

  var inactiveText: Text? {
    switch self {
    case let .played(rank: rank, outOf: outOf):
      return Text("Played\n#\(rank) of \(outOf)")
    case .resume:
      return nil
    case .playable:
      return nil
    case .unplayable:
      return Text("Played")
    }
  }

  var resumeText: Text? {
    switch self {
    case .played:
      return nil
    case let .resume(currentScore: currentScore):
      return currentScore > 0 ? Text("\(currentScore) pts") : nil
    case .playable:
      return nil
    case .unplayable:
      return nil
    }
  }
}

private let relativeFormatter = RelativeDateTimeFormatter()

private struct ReminderBell: View {
  @State var shake = false
  let action: () -> Void

  var body: some View {
    Button(action: self.action) {
      Image(systemName: "bell.badge.fill")
        .font(.system(size: 20))
        .modifier(RingEffect(animatableData: CGFloat(self.shake ? 1 : 0)))
        .onAppear {
          withAnimation(Animation.easeInOut(duration: 1).delay(2)) {
            self.shake = true
          }
        }
    }
  }
}

private struct RingEffect: GeometryEffect {
  var animatableData: CGFloat

  func effectValue(size: CGSize) -> ProjectionTransform {
    ProjectionTransform(
      CGAffineTransform(rotationAngle: -.pi / 30 * sin(animatableData * .pi * 10))
    )
  }
}

#if DEBUG
  import SwiftUIHelpers

  struct DailyChallengeView_Previews: PreviewProvider {
    static var previews: some View {
      var environment = DailyChallengeEnvironment(
        apiClient: .noop,
        fileClient: .noop,
        mainQueue: .immediate,
        mainRunLoop: .immediate,
        remoteNotifications: .noop,
        userNotifications: .noop
      )
      environment.userNotifications.getNotificationSettings = .init(
        value: .init(authorizationStatus: .notDetermined))

      return Preview {
        NavigationView {
          DailyChallengeView(
            store: .init(
              initialState: .init(
                inProgressDailyChallengeUnlimited: update(.mock) {
                  $0?.moves = [.highScoringMove]
                }
              ),
              reducer: dailyChallengeReducer,
              environment: environment
            )
          )
        }
      }
    }
  }
#endif
