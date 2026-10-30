import Combine
import ComposableArchitecture
import ComposableUserNotifications
import Dependencies
import NotificationHelpers
import RemoteNotificationsClient
import Styleguide
import SwiftUI

@Feature
public struct NotificationsAuthAlert {
  public struct State {
    public init() {}
  }

  public enum Action {
    case turnOnNotificationsButtonTapped
  }

  public enum DidChooseNotificationSettings: FeatureEventKey {
    public typealias Value = UserNotificationClient.Notification.Settings
  }

  @Dependency(\.remoteNotifications) var remoteNotifications
  @Dependency(\.userNotifications) var userNotifications

  public init() {}

  public var body: some Feature {
    Update { state, action in
      switch action {
      case .turnOnNotificationsButtonTapped:
        store.addTask {
          if try await userNotifications.requestAuthorization([.alert, .sound]) {
            await registerForRemoteNotificationsAsync(
              remoteNotifications: remoteNotifications,
              userNotifications: userNotifications
            )
          }
          let settings = await userNotifications.getNotificationSettings()
          try withAnimation {
            _ = try store.post(key: DidChooseNotificationSettings.self, value: settings)
          }
          try store.dismiss()
        }
      }
    }
  }
}

extension View {
  public func notificationsAlert(
    _ store: Binding<Store<NotificationsAuthAlert.State, NotificationsAuthAlert.Action>?>
  ) -> some View {
    modifier(NotificationsAuthAlertViewModifier(store: store))
  }
}

struct NotificationsAuthAlertViewModifier: ViewModifier {
  @Binding var store: Store<NotificationsAuthAlert.State, NotificationsAuthAlert.Action>?

  func body(content: Content) -> some View {
    let isPresented = store != nil
    content
      .overlay {
        if isPresented {
          Rectangle()
            .fill(Color.dailyChallenge.opacity(0.8))
            .ignoresSafeArea()
            .transition(.opacity.animation(.default))
        }
      }
      .overlay {
        if isPresented {
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
