import ClientModels
import ComposableArchitecture
import ComposableUserNotifications
import DailyChallengeHelpers
import DateHelpers
import Dependencies
import NotificationsAuthAlert
import Overture
import SharedModels
import Styleguide
import SwiftUI

@Feature
public struct DailyChallengeReducer {
  @Feature
  public enum Destination {
    case alert(Alert)
    case notificationsAuthAlert(NotificationsAuthAlert)
    case results(DailyChallengeResults)

    @Feature
    public struct Alert: Prompt {
      public struct State {
        public var message: Text
        public var title: Text

        public init(title: Text, message: Text) {
          self.message = message
          self.title = title
        }
      }
    }
  }

  public struct State {
    public var dailyChallenges: [FetchTodaysDailyChallengeResponse]
    public var destination: Destination.State?
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

    var isNotificationStatusDetermined: Bool {
      ![.notDetermined, .provisional]
         .contains(self.userNotificationSettings?.authorizationStatus)
    }
  }

  public enum Action {
    case destination(Destination.Action)
    case gameButtonTapped(GameMode)
    case notificationButtonTapped
    case resultsButtonTapped
  }

  public enum StartGame: FeatureEventKey {
    public typealias Value = InProgressGame
  }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.fileClient) var fileClient
  @FeatureEnvironment(\.date.now) var now
  @Dependency(\.userNotifications.getNotificationSettings) var getUserNotificationSettings

  public init() {}

  public var body: some Feature {
    Update { state, action in
      switch action {
      case .destination:
        break

      case let .gameButtonTapped(gameMode):
        guard
          let challenge = state.dailyChallenges
            .first(where: { $0.dailyChallenge.gameMode == gameMode })
        else { return }

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
          return
        }

        state.gameModeIsLoading = challenge.dailyChallenge.gameMode

        store.addTask {
          do {
            let inProgressGame = try await startDailyChallengeAsync(
              challenge,
              apiClient: apiClient,
              date: { now },
              fileClient: fileClient
            )
            try store.modify { $0.gameModeIsLoading = nil }
            try store.post(key: StartGame.self, value: inProgressGame)
          } catch let DailyChallengeError.alreadyPlayed(endsAt) {
            try store.modify {
              $0.destination = .alert(.alreadyPlayed(nextStartsAt: endsAt))
              $0.gameModeIsLoading = nil
            }
          } catch let DailyChallengeError.couldNotFetch(nextStartsAt) {
            try store.modify {
              $0.destination = .alert(.couldNotFetchDaily(nextStartsAt: nextStartsAt))
              $0.gameModeIsLoading = nil
            }
          } catch {}
        }

      case .notificationButtonTapped:
        state.destination = .notificationsAuthAlert(NotificationsAuthAlert.State())

      case .resultsButtonTapped:
        state.destination = .results(DailyChallengeResults.State())
      }
    }
    .ifLet(\.destination) {
      Destination.body
    }
    .onEvent(NotificationsAuthAlert.DidChooseNotificationSettings.self) { settings, state in
      state.userNotificationSettings = settings
    }
    .onMount { _ in
      store.addTask {
        let settings = await getUserNotificationSettings()
        try store.modify { $0.userNotificationSettings = settings }
      }
      store.addTask {
        let dailyChallenges = try await apiClient.apiRequest(
          route: .dailyChallenge(.today(language: .en)),
          as: [FetchTodaysDailyChallengeResponse].self
        )
        try await MainActor.run {
          try withAnimation {
            _ = try store.modify { $0.dailyChallenges = dailyChallenges }
          }
        }
      }
    }
  }
}

extension DailyChallengeReducer.Destination.Alert.State {
  static func alreadyPlayed(nextStartsAt: Date) -> Self {
    Self(
      title: Text("Already played"),
      message: Text(
        """
        You already played today’s daily challenge. You can play the next one in \
        \(nextStartsAt, formatter: relativeFormatter).
        """
      )
    )
  }

  static func couldNotFetchDaily(nextStartsAt: Date) -> Self {
    Self(
      title: Text("Couldn’t start today’s daily"),
      message: Text(
        """
        We’re sorry. We were unable to fetch today’s daily or you already started it \
        earlier today. You can play the next daily in \(nextStartsAt, formatter: relativeFormatter).
        """
      )
    )
  }
}

public struct DailyChallengeView: View {
  @Environment(\.adaptiveSize) var adaptiveSize
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.date) var date
  @Bindable var store: StoreOf<DailyChallengeReducer>

  enum ButtonState: Equatable {
    case played(rank: Int, outOf: Int)
    case playable
    case resume(currentScore: Int)
    case unplayable
  }

  var timedState: ButtonState {
    .init(
      fetchedResponse: store.dailyChallenges.timed,
      inProgressGame: nil
    )
  }

  var unlimitedState: ButtonState {
    .init(
      fetchedResponse: store.dailyChallenges.unlimited,
      inProgressGame: store.inProgressDailyChallengeUnlimited
    )
  }

  public init(store: StoreOf<DailyChallengeReducer>) {
    self.store = store
  }

  public var body: some View {
    GeometryReader { proxy in
      VStack {
        Spacer()
          .frame(maxHeight: .grid(16))

        VStack(spacing: .grid(8)) {
          Group {
            if store.dailyChallenges.numberOfPlayers <= 1 {
              (Text("Play")
                + Text("\nagainst the")
                + Text("\ncommunity"))
            } else {
              (Text("\(store.dailyChallenges.numberOfPlayers)")
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
            inactiveText: timedState.inactiveText,
            isLoading: store.gameModeIsLoading == .timed,
            resumeText: timedState.resumeText,
            action: { withAnimation { _ = store.send(.gameButtonTapped(.timed)) } }
          )
          .disabled(store.gameModeIsLoading != nil)

          GameButton(
            title: Text("Unlimited"),
            icon: Image(systemName: "infinity"),
            color: .dailyChallenge,
            inactiveText: unlimitedState.inactiveText,
            isLoading: store.gameModeIsLoading == .unlimited,
            resumeText: unlimitedState.resumeText,
            action: { withAnimation { _ = store.send(.gameButtonTapped(.unlimited)) } }
          )
          .disabled(store.gameModeIsLoading != nil)
        }
        .adaptivePadding(.vertical)
        .screenEdgePadding(.horizontal)

        Button {
          store.send(.resultsButtonTapped)
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
      .navigationStyle(
        backgroundColor: self.colorScheme == .dark ? .isowordsBlack : .dailyChallenge,
        foregroundColor: self.colorScheme == .dark ? .dailyChallenge : .isowordsBlack,
        title: Text("Daily Challenge"),
        trailing: Group {
          if !store.isNotificationStatusDetermined {
            ReminderBell {
              withAnimation { _ = store.send(.notificationButtonTapped) }
            }
            .transition(
              .scale(scale: 0)
                .animation(.easeOut.delay(1))
            )
          }
        }
      )
      .edgesIgnoringSafeArea(.bottom)
    }
    .alert(
      store.destination?.alert?.title ?? Text(""),
      isPresented: Binding(
        get: { store.destination?.alert != nil },
        set: { isPresented in
          if !isPresented {
            $store.scope(\.destination).alert.wrappedValue = nil
          }
        }
      ),
      presenting: store.destination?.alert
    ) { _ in
      Button("OK") {}
    } message: { alert in
      alert.message
    }
    .navigationDestination(item: $store.scope(\.destination).results) { store in
      DailyChallengeResultsView(store: store)
    }
    .notificationsAlert($store.scope(\.destination).notificationsAuthAlert)
  }
}

extension DailyChallengeView.ButtonState {
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
          withAnimation(.easeInOut(duration: 1).delay(2)) {
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
              )
            ) {
              DailyChallengeReducer()
                .dependency(\.userNotifications.getNotificationSettings) {
                  .init(authorizationStatus: .notDetermined)
                }
            }
          )
        }
      }
    }
  }
#endif
