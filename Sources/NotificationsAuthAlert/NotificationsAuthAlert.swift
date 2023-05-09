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
    case delegate(Delegate)
    case turnOnNotificationsButtonTapped

    public enum Delegate: Equatable {
      case didChooseNotificationSettings(UserNotificationClient.Notification.Settings)
    }
  }

  @Dependency(\.dismiss) var dismiss
  @Dependency(\.remoteNotifications) var remoteNotifications
  @Dependency(\.userNotifications) var userNotifications

  public init() {}

  public func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .closeButtonTapped:
      return .fireAndForget {
        await self.dismiss()
      }

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

extension View {
  public func notificationsAlert<DestinationState, DestinationAction>(
    store: Store<PresentationState<DestinationState>, PresentationAction<DestinationAction>>,
    state toAlertState: @escaping (DestinationState) -> NotificationsAuthAlert.State?,
    action fromAlertAction: @escaping (NotificationsAuthAlert.Action) -> DestinationAction
  ) -> some View {
    WithViewStore(
      store.scope(state: { $0.wrappedValue.flatMap(toAlertState) != nil }), observe: { $0 }
    ) { viewStore in
      self
        .overlay {
          if viewStore.state {
            Rectangle()
              .fill(Color.dailyChallenge.opacity(0.8))
              .ignoresSafeArea()
              .transition(.opacity.animation(.default))
          }
        }
        .overlay {
          IfLetStore(
            store,
            state: toAlertState,
            action: fromAlertAction
          ) {
            NotificationsAuthAlertView(store: $0)
              .transition(
                .scale(scale: 0.8, anchor: .center)
                .animation(.spring())
                .combined(with: .opacity.animation(.default))
              )
          }
        }
    }
  }
}

struct NotificationsAuthAlertView: View {
  let store: StoreOf<NotificationsAuthAlert>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      ZStack(alignment: .topTrailing) {
        VStack(spacing: .grid(8)) {
          (Text("Want to get notified about ")
            + Text("your ranks?").fontWeight(.medium))
            .adaptiveFont(.matter, size: 28)
            .foregroundColor(.dailyChallenge)
            .lineLimit(.max)
            .minimumScaleFactor(0.2)
            .multilineTextAlignment(.center)

          Button("Turn on notifications") {
            viewStore.send(.turnOnNotificationsButtonTapped, animation: .default)
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
