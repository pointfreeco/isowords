import Combine
import ComposableArchitecture
import ComposableUserNotifications
import NotificationHelpers
import RemoteNotificationsClient
import Styleguide
import SwiftUI

@Reducer
public struct NotificationsAuthAlert {
  public struct State: Equatable {
    public init() {}
  }

  public enum Action {
    case delegate(Delegate)
    case turnOnNotificationsButtonTapped

    @CasePathable
    public enum Delegate {
      case didChooseNotificationSettings(UserNotificationClient.Notification.Settings)
    }
  }

  @Dependency(\.dismiss) var dismiss
  @Dependency(\.remoteNotifications) var remoteNotifications
  @Dependency(\.userNotifications) var userNotifications

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
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
          await self.dismiss()
        }
      }
    }
  }
}

extension View {
  public func notificationsAlert(
    _ store: Binding<Store<NotificationsAuthAlert.State, NotificationsAuthAlert.Action>?>
  ) -> some View {
    self.modifier(NotificationsAuthAlertViewModifier(store: store))
  }
}

struct NotificationsAuthAlertViewModifier: ViewModifier {
  @Binding var store: Store<NotificationsAuthAlert.State, NotificationsAuthAlert.Action>?

  func body(content: Content) -> some View {
    let state = store?.withState { $0 }
    content
      .overlay {
        if state != nil {
          Rectangle()
            .fill(Color.dailyChallenge.opacity(0.8))
            .ignoresSafeArea()
            .transition(.opacity.animation(.default))
        }
      }
      .overlay {
        if state != nil {
          ZStack(alignment: .topTrailing) {
            NotificationsAuthAlertView {
              store?.send(.turnOnNotificationsButtonTapped)
            }

            Button {
              store = nil
            } label: {
              Image(systemName: "xmark")
                .font(.system(size: 20))
                .foregroundColor(.dailyChallenge)
                .padding(.grid(5))
            }
          }
          .transition(
            .scale(scale: 0.8, anchor: .center)
            .animation(.spring())
            .combined(with: .opacity.animation(.default))
          )
        }
      }
  }
}

struct NotificationsAuthAlertView: View {
  let action: () -> Void

  var body: some View {
    VStack(spacing: .grid(8)) {
      (Text("Want to get notified about ")
       + Text("your ranks?").fontWeight(.medium))
      .adaptiveFont(.matter, size: 28)
      .foregroundColor(.dailyChallenge)
      .lineLimit(.max)
      .minimumScaleFactor(0.2)
      .multilineTextAlignment(.center)

      Button("Turn on notifications") {
        withAnimation {
          action()
        }
      }
      .buttonStyle(ActionButtonStyle(backgroundColor: .dailyChallenge, foregroundColor: .black))
    }
    .padding(.top, .grid(4))
    .padding(.grid(8))
    .background(Color.black)
  }
}

struct NotificationMenu_Previews: PreviewProvider {
  static var previews: some View {
    NotificationsAuthAlertView(action: {})
  }
}
