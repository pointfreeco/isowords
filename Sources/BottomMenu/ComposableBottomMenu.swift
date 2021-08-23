import ComposableArchitecture
import SwiftUI

public struct BottomMenuState<Action> {
  public var buttons: [Button]
  public var footerButton: Button?
  public var message: TextState?
  public var onDismiss: MenuAction?
  public var title: TextState

  public init(
    title: TextState,
    message: TextState? = nil,
    buttons: [Button] = [],
    footerButton: Button? = nil,
    onDismiss: MenuAction? = nil
  ) {
    self.buttons = buttons
    self.footerButton = footerButton
    self.message = message
    self.onDismiss = onDismiss
    self.title = title
  }

  public struct Button {
    public let action: MenuAction?
    public let icon: Image
    public let title: TextState

    public init(
      title: TextState,
      icon: Image,
      action: MenuAction? = nil
    ) {
      self.action = action
      self.icon = icon
      self.title = title
    }
  }

  public struct MenuAction {
    public let action: Action
    fileprivate let animation: Animation

    fileprivate enum Animation: Equatable {
      case inherited
      case explicit(SwiftUI.Animation?)
    }

    public init(
      action: Action,
      animation: SwiftUI.Animation?
    ) {
      self.action = action
      self.animation = .explicit(animation)
    }

    public init(
      action: Action
    ) {
      self.action = action
      self.animation = .inherited
    }
  }
}

extension BottomMenuState: Equatable where Action: Equatable {}
extension BottomMenuState.Button: Equatable where Action: Equatable {}
extension BottomMenuState.MenuAction: Equatable where Action: Equatable {}

extension View {
  public func bottomMenu<Action>(
    _ store: Store<BottomMenuState<Action>?, Action>
  ) -> some View where Action: Equatable {
    WithViewStore(store) { viewStore in
      self.bottomMenu(
        item: Binding(
          get: {
            viewStore.state?.converted(send: viewStore.send, sendWithAnimation: viewStore.send)
          },
          set: { state, transaction in
            withAnimation(transaction.disablesAnimations ? nil : transaction.animation) {
              if state == nil, let onDismiss = viewStore.state?.onDismiss {
                switch onDismiss.animation {
                case .inherited:
                  viewStore.send(onDismiss.action)
                case let .explicit(animation):
                  viewStore.send(onDismiss.action, animation: animation)
                }
              }
            }
          }
        )
      )
    }
  }
}

extension BottomMenuState {
  fileprivate func converted(
    send: @escaping (Action) -> Void,
    sendWithAnimation: @escaping (Action, Animation?) -> Void
  ) -> BottomMenu {
    .init(
      title: Text(self.title),
      message: self.message.map { Text($0) },
      buttons: self.buttons.map { $0.converted(send: send, sendWithAnimation: sendWithAnimation) },
      footerButton: self.footerButton.map {
        $0.converted(send: send, sendWithAnimation: sendWithAnimation)
      }
    )
  }
}

extension BottomMenuState.Button {
  fileprivate func converted(
    send: @escaping (Action) -> Void,
    sendWithAnimation: @escaping (Action, Animation?) -> Void
  ) -> BottomMenu.Button {
    .init(
      title: Text(self.title),
      icon: self.icon,
      action: {
        if let action = self.action {
          switch action.animation {
          case .inherited:
            send(action.action)
          case let .explicit(animation):
            sendWithAnimation(action.action, animation)
          }
        }
      }
    )
  }
}

#if DEBUG
  import ComposableArchitecture
  import SwiftUIHelpers

  private enum Action {
    case show
    case dismiss
  }

  private let reducer = Reducer<BottomMenuState<Action>?, Action, Void> { state, action, _ in
    switch action {
    case .show:
      state = .init(
        title: .init("vs mbrandonw"),
        buttons: [
          .init(
            title: .init("Main menu"),
            icon: Image(systemName: "flag")
          ),
          .init(
            title: .init("End game"),
            icon: Image(systemName: "flag")
          ),
        ],
        footerButton: .init(
          title: .init("Settings"),
          icon: Image(systemName: "gear")
        ),
        onDismiss: .init(action: .dismiss, animation: .default)
      )
      return .none
    case .dismiss:
      state = nil
      return .none
    }
  }

  struct BottomMenu_TCA_Previews: PreviewProvider {
    struct TestView: View {
      private let store = Store(
        initialState: nil,
        reducer: reducer,
        environment: ()
      )

      var body: some View {
        WithViewStore(self.store.stateless) { viewStore in
          Button("Present") { viewStore.send(.show, animation: .default) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .bottomMenu(self.store)
        }
      }
    }

    static var previews: some View {
      Preview {
        TestView()
      }
    }
  }
#endif
