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
    self.modifier(
      NotificationsAuthAlertViewModifier(
        store: store, toAlertState: toAlertState, fromAlertAction: fromAlertAction
      )
    )
  }
}

struct NotificationsAuthAlertViewModifier<DestinationState, DestinationAction>: ViewModifier {
  let store: Store<PresentationState<DestinationState>, PresentationAction<DestinationAction>>
  let toAlertState: (DestinationState) -> NotificationsAuthAlert.State?
  let fromAlertAction: (NotificationsAuthAlert.Action) -> DestinationAction

  func body(content: Content) -> some View {
    WithViewStore(
      self.store.scope(state: { $0.wrappedValue.flatMap(self.toAlertState) }),
      observe: { $0 }
    ) { viewStore in
      content
        .overlay {
          if viewStore.state != nil {
            Rectangle()
              .fill(Color.dailyChallenge.opacity(0.8))
              .ignoresSafeArea()
              .transition(.opacity.animation(.default))
          }
        }
        .overlay {
          if let state = viewStore.state {
            ZStack(alignment: .topTrailing) {
              NotificationsAuthAlertView(
                store: store.scope(
                  state: { _ in state }, action: { .presented(fromAlertAction($0)) }
                )
              )

              Button(action: { viewStore.send(.dismiss) }) {
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
}

struct NotificationsAuthAlertView: View {
  let store: StoreOf<NotificationsAuthAlert>

  var body: some View {
    WithViewStore(self.store) { viewStore in
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
