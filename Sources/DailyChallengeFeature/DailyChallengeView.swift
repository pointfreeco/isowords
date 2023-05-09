import ClientModels
import ComposableArchitecture
import ComposableUserNotifications
import DailyChallengeHelpers
import DateHelpers
import NotificationsAuthAlert
import Overture
import SharedModels
import Styleguide
import SwiftUI

public struct DailyChallengeReducer: ReducerProtocol {
  public struct Destination: ReducerProtocol {
    public enum State: Equatable {
      case alert(AlertState<Action.Alert>)
      case notificationsAuthAlert(NotificationsAuthAlert.State = .init())
      case results(DailyChallengeResults.State = .init())
    }
    public enum Action: Equatable {
      case alert(Alert)
      case notificationsAuthAlert(NotificationsAuthAlert.Action)
      case results(DailyChallengeResults.Action)

      public enum Alert: Equatable {}
    }
    public var body: some ReducerProtocol<State, Action> {
      Scope(state: /State.notificationsAuthAlert, action: /Action.notificationsAuthAlert) {
        NotificationsAuthAlert()
      }
      Scope(state: /State.results, action: /Action.results) {
        DailyChallengeResults()
      }
    }
  }

  public struct State: Equatable {
    public var dailyChallenges: [FetchTodaysDailyChallengeResponse]
    @PresentationState public var destination: Destination.State?
    public var gameModeIsLoading: GameMode?
    public var inProgressDailyChallengeUnlimited: InProgressGame?
    public var userNotificationSettings: UserNotificationClient.Notification.Settings?

    public init(
      dailyChallenges: [FetchTodaysDailyChallengeResponse] = [],
      destination: Destination.State? = nil,
      gameModeIsLoading: GameMode? = nil,
      inProgressDailyChallengeUnlimited: InProgressGame? = nil,
      userNotificationSettings: UserNotificationClient.Notification.Settings? = nil
    ) {
      self.dailyChallenges = dailyChallenges
      self.destination = destination
      self.gameModeIsLoading = gameModeIsLoading
      self.inProgressDailyChallengeUnlimited = inProgressDailyChallengeUnlimited
      self.userNotificationSettings = userNotificationSettings
    }
  }

  public enum Action: Equatable {
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case fetchTodaysDailyChallengeResponse(TaskResult<[FetchTodaysDailyChallengeResponse]>)
    case gameButtonTapped(GameMode)
    case notificationButtonTapped
    case resultsButtonTapped
    case startDailyChallengeResponse(TaskResult<InProgressGame>)
    case task
    case userNotificationSettingsResponse(UserNotificationClient.Notification.Settings)

    public enum Delegate: Equatable {
      case startGame(InProgressGame)
    }
  }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.fileClient) var fileClient
  @Dependency(\.mainRunLoop.now.date) var now
  @Dependency(\.userNotifications.getNotificationSettings) var getUserNotificationSettings

  public init() {}

  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .delegate:
        return .none

      case let .destination(
        .presented(.notificationsAuthAlert(.delegate(.didChooseNotificationSettings(settings))))
      ):
        state.userNotificationSettings = settings
        return .none

      case .destination:
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
          isPlayable =
            !challenge.yourResult.started || state.inProgressDailyChallengeUnlimited != nil
        }

        guard isPlayable
        else {
          state.destination = .alert(.alreadyPlayed(nextStartsAt: challenge.dailyChallenge.endsAt))
          return .none
        }

        state.gameModeIsLoading = challenge.dailyChallenge.gameMode

        return .task {
          await .startDailyChallengeResponse(
            TaskResult {
              try await startDailyChallengeAsync(
                challenge,
                apiClient: self.apiClient,
                date: { self.now },
                fileClient: self.fileClient
              )
            }
          )
        }

      case .notificationButtonTapped:
        state.destination = .notificationsAuthAlert(.init())
        return .none

      case .resultsButtonTapped:
        state.destination = .results(.init())
        return .none

      case let .startDailyChallengeResponse(.failure(DailyChallengeError.alreadyPlayed(endsAt))):
        state.destination = .alert(.alreadyPlayed(nextStartsAt: endsAt))
        state.gameModeIsLoading = nil
        return .none

      case let .startDailyChallengeResponse(
        .failure(DailyChallengeError.couldNotFetch(nextStartsAt))
      ):
        state.destination = .alert(.couldNotFetchDaily(nextStartsAt: nextStartsAt))
        state.gameModeIsLoading = nil
        return .none

      case .startDailyChallengeResponse(.failure):
        return .none

      case let .startDailyChallengeResponse(.success(inProgressGame)):
        state.gameModeIsLoading = nil
        return .task { .delegate(.startGame(inProgressGame)) }

      case .task:
        return .run { send in
          await withTaskGroup(of: Void.self) { group in
            group.addTask {
              await send(
                .userNotificationSettingsResponse(
                  self.getUserNotificationSettings()
                )
              )
            }

            group.addTask {
              await send(
                .fetchTodaysDailyChallengeResponse(
                  TaskResult {
                    try await self.apiClient.apiRequest(
                      route: .dailyChallenge(.today(language: .en)),
                      as: [FetchTodaysDailyChallengeResponse].self
                    )
                  }
                ),
                animation: .default
              )
            }
          }
        }

      case let .userNotificationSettingsResponse(settings):
        state.userNotificationSettings = settings
        return .none
      }
    }
    .ifLet(\.$destination, action: /Action.destination) {
      Destination()
    }
  }
}

extension AlertState where Action == DailyChallengeReducer.Destination.Action.Alert {
  static func alreadyPlayed(nextStartsAt: Date) -> Self {
    Self {
      TextState("Already played")
    } actions: {
      ButtonState {
        TextState("OK")
      }
    } message: {
      TextState(
        """
        You already played today’s daily challenge. You can play the next one in \
        \(nextStartsAt, formatter: relativeFormatter).
        """
      )
    }
  }

  static func couldNotFetchDaily(nextStartsAt: Date) -> Self {
    Self {
      TextState("Couldn’t start today’s daily")
    } actions: {
      ButtonState {
        TextState("OK")
      }
    } message: {
      TextState(
        """
        We’re sorry. We were unable to fetch today’s daily or you already started it \
        earlier today. You can play the next daily in \(nextStartsAt, formatter: relativeFormatter).
        """
      )
    }
  }
}

public struct DailyChallengeView: View {
  @Environment(\.adaptiveSize) var adaptiveSize
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.date) var date
  let store: StoreOf<DailyChallengeReducer>
  @ObservedObject var viewStore: ViewStore<ViewState, DailyChallengeReducer.Action>

  struct ViewState: Equatable {
    let gameModeIsLoading: GameMode?
    let isNotificationStatusDetermined: Bool
    let numberOfPlayers: Int
    let timedState: ButtonState
    let unlimitedState: ButtonState

    enum ButtonState: Equatable {
      case played(rank: Int, outOf: Int)
      case playable
      case resume(currentScore: Int)
      case unplayable
    }

    init(state: DailyChallengeReducer.State) {
      self.gameModeIsLoading = state.gameModeIsLoading
      self.isNotificationStatusDetermined = ![.notDetermined, .provisional]
        .contains(state.userNotificationSettings?.authorizationStatus)
      self.numberOfPlayers = state.dailyChallenges.numberOfPlayers
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

  public init(store: StoreOf<DailyChallengeReducer>) {
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
        .adaptivePadding(.vertical)
        .screenEdgePadding(.horizontal)

        Button {
          viewStore.send(.resultsButtonTapped)
        } label: {
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
        .foregroundColor(self.colorScheme == .dark ? .isowordsBlack : .dailyChallenge)
        .background(self.colorScheme == .dark ? Color.dailyChallenge : .isowordsBlack)
      }
      .task { await self.viewStore.send(.task).finish() }
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
    .alert(
      store: self.store.scope(
        state: \.$destination,
        action: DailyChallengeReducer.Action.destination
      ),
      state: /DailyChallengeReducer.Destination.State.alert,
      action: DailyChallengeReducer.Destination.Action.alert
    )
    .navigationDestination(
      store: self.store.scope(
        state: \.$destination,
        action: DailyChallengeReducer.Action.destination
      ),
      state: /DailyChallengeReducer.Destination.State.results,
      action: DailyChallengeReducer.Destination.Action.results,
      destination: DailyChallengeResultsView.init(store:)
    )
    .notificationsAlert(
      store: self.store.scope(
        state: \.$destination,
        action: DailyChallengeReducer.Action.destination
      ),
      state: /DailyChallengeReducer.Destination.State.notificationsAuthAlert,
      action: DailyChallengeReducer.Destination.Action.notificationsAuthAlert
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
      Preview {
        NavigationView {
          DailyChallengeView(
            store: .init(
              initialState: DailyChallengeReducer.State(
                inProgressDailyChallengeUnlimited: update(.mock) {
                  $0?.moves = [.highScoringMove]
                }
              ),
              reducer: DailyChallengeReducer()
                .dependency(\.userNotifications.getNotificationSettings) {
                  .init(authorizationStatus: .notDetermined)
                }
            )
          )
        }
      }
    }
  }
#endif
