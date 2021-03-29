import Combine
import CombineHelpers
import ComposableArchitecture
import ComposableUserNotifications
import NotificationHelpers
import RemoteNotificationsClient
import Styleguide
import SwiftUI

public struct NotificationsAuthAlertState: Equatable {
  public init() {}
}

public enum NotificationsAuthAlertAction: Equatable {
  case closeButtonTapped
  case delegate(DelegateAction)
  case turnOnNotificationsButtonTapped

  public enum DelegateAction: Equatable {
    case close
    case didChooseNotificationSettings(UserNotificationClient.Notification.Settings)
  }
}

public struct NotificationsAuthAlertEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var remoteNotifications: RemoteNotificationsClient
  var userNotifications: UserNotificationClient

  public init(
    mainQueue: AnySchedulerOf<DispatchQueue>,
    remoteNotifications: RemoteNotificationsClient,
    userNotifications: UserNotificationClient
  ) {
    self.mainQueue = mainQueue
    self.remoteNotifications = remoteNotifications
    self.userNotifications = userNotifications
  }
}

public let notificationsAuthAlertReducer = Reducer<
  NotificationsAuthAlertState,
  NotificationsAuthAlertAction,
  NotificationsAuthAlertEnvironment
> { state, action, environment in
  switch action {
  case .closeButtonTapped:
    return Effect(value: .delegate(.close))
      .receive(on: ImmediateScheduler.shared.animation())
      .eraseToEffect()

  case .delegate:
    return .none

  case .turnOnNotificationsButtonTapped:
    return .concatenate(
      environment.userNotifications.requestAuthorization([.alert, .sound])
        .ignoreFailure()
        .flatMap { successful in
          successful
            ? Effect.registerForRemoteNotifications(
              mainQueue: environment.mainQueue,
              remoteNotifications: environment.remoteNotifications,
              userNotifications: environment.userNotifications
            )
            : .none
        }
        .eraseToEffect()
        .fireAndForget(),

      environment.userNotifications.getNotificationSettings
        .flatMap { settings in
          Effect(value: .delegate(.didChooseNotificationSettings(settings)))
            .receive(on: environment.mainQueue.animation())
        }
        .eraseToEffect()
    )
  }
}

extension View {
  public func notificationsAlert(
    store: Store<NotificationsAuthAlertState?, NotificationsAuthAlertAction>
  ) -> some View {
    ZStack {
      self

      IfLetStore(
        store,
        then: NotificationsAuthAlert.init(store:)
      )
      // NB: This is necessary so that when the alert is animated away it stays above `self`.
      .zIndex(1)
    }
  }
}

struct NotificationsAuthAlert: View {
  let store: Store<NotificationsAuthAlertState, NotificationsAuthAlertAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Rectangle()
        .fill(Color.dailyChallenge.opacity(0.8))
        .ignoresSafeArea()

      ZStack(alignment: .topTrailing) {
        VStack(spacing: .grid(8)) {
          (Text("Want to get notified about ")
            + Text("your ranks?").fontWeight(.medium))
            .adaptiveFont(.matter, size: 28)
            .foregroundColor(.dailyChallenge)
            .lineLimit(.max)
            .minimumScaleFactor(0.2)
            .multilineTextAlignment(.center)

          Button(action: { viewStore.send(.turnOnNotificationsButtonTapped, animation: .default) })
          {
            Text("Turn on notifications")
          }
          .buttonStyle(ActionButtonStyle(backgroundColor: .dailyChallenge, foregroundColor: .black))
        }
        .padding(.top, .grid(4))
        .padding(.grid(8))
        .background(Color.black)

        Button(action: { viewStore.send(.closeButtonTapped, animation: .default) }) {
          Image(systemName: "xmark")
            .font(.system(size: 20))
            .foregroundColor(.dailyChallenge)
            .padding(.grid(5))
        }
      }
      .transition(
        AnyTransition.scale(scale: 0.8, anchor: .center)
          .animation(.spring())
          .combined(with: .opacity)
      )
    }
  }
}

struct NotificationMenu_Previews: PreviewProvider {
  static var previews: some View {
    NotificationsAuthAlert(
      store: Store(
        initialState: NotificationsAuthAlertState(),
        reducer: notificationsAuthAlertReducer,
        environment: NotificationsAuthAlertEnvironment(
          mainQueue: .main,
          remoteNotifications: .noop,
          userNotifications: .noop
        )
      )
    )
  }
}
