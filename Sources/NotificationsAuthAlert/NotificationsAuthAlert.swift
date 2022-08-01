import Combine
import CombineHelpers
import ComposableArchitecture
import ComposableUserNotifications
import NotificationHelpers
import RemoteNotificationsClient
import Styleguide
import SwiftUI

public struct NotificationsAuthAlert: ReducerProtocol {
  public struct State: Equatable {
    public init() {}
  }

  public enum Action: Equatable {
    case closeButtonTapped
    case delegate(DelegateAction)
    case turnOnNotificationsButtonTapped
  }

  public enum DelegateAction: Equatable {
    case close
    case didChooseNotificationSettings(UserNotificationClient.Notification.Settings)
  }

  @Dependency(\.mainRunLoop) var mainRunLoop
  @Dependency(\.remoteNotifications) var remoteNotifications
  @Dependency(\.userNotifications) var userNotifications

  public init() {}

  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    switch action {
    case .closeButtonTapped:
      return .task { .delegate(.close) }.animation()

    case .delegate:
      return .none

    case .turnOnNotificationsButtonTapped:
      return .run { send in
        if try await self.userNotifications.requestAuthorization([.alert, .sound]) {
          await registerForRemoteNotificationsAsync(
            remoteNotifications: self.remoteNotifications,
            userNotifications: self.userNotifications
          )
        }
        await send(
          .delegate(
            .didChooseNotificationSettings(self.userNotifications.getNotificationSettings())
          ),
          animation: .default
        )
      }
    }
  }
}

extension View {
  public func notificationsAlert(
    store: Store<NotificationsAuthAlert.State?, NotificationsAuthAlert.Action>
  ) -> some View {
    ZStack {
      self

      IfLetStore(
        store,
        then: NotificationsAuthAlertView.init(store:)
      )
      // NB: This is necessary so that when the alert is animated away it stays above `self`.
      .zIndex(1)
    }
  }
}

struct NotificationsAuthAlertView: View {
  let store: StoreOf<NotificationsAuthAlert>

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
    NotificationsAuthAlertView(
      store: Store(
        initialState: NotificationsAuthAlert.State(),
        reducer: NotificationsAuthAlert()
      )
    )
  }
}
