import ComposableArchitecture
import SwiftUI

public struct BottomMenuState<Action> {
  public var buttons: [Button]
  public var footerButton: Button?
  public var message: TextState?
  public var title: TextState

  public init(
    title: TextState,
    message: TextState? = nil,
    buttons: [Button] = [],
    footerButton: Button? = nil
  ) {
    self.buttons = buttons
    self.footerButton = footerButton
    self.message = message
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
extension BottomMenuState: _EphemeralState {
  public static var actionType: Any.Type { Action.self }
}

extension View {
  public func bottomMenu<MenuAction: Equatable>(
    store: Binding<Store<BottomMenuState<MenuAction>, MenuAction>?>
  ) -> some View {
    self.bottomMenu(
      item: Binding(
        get: {
          store.wrappedValue?.withState { $0 }.converted(
            send: {
              store.wrappedValue?.send($0)
            },
            sendWithAnimation: {
              store.wrappedValue?.send($0, animation: $1)
            }
          )
        },
        set: { state in
          if state == nil {
            store.wrappedValue = nil
          }
        }
      )
    )
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

  @Reducer
  private struct BottomMenuReducer {
    struct State: Equatable {
      @PresentationState var bottomMenu: BottomMenuState<Action.BottomMenu>?
    }

    enum Action: Equatable {
      case bottomMenu(PresentationAction<BottomMenu>)
      case showMenuButtonTapped

      enum BottomMenu: Equatable {}
    }

    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .showMenuButtonTapped:
          state.bottomMenu = .init(
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
            )
          )
          return .none
        case .bottomMenu:
          return .none
        }
      }
      .ifLet(\.$bottomMenu, action: \.bottomMenu)
    }
  }

//  struct BottomMenu_TCA_Previews: PreviewProvider {
//    struct TestView: View {
//      @State fileprivate var store = Store(initialState: BottomMenuReducer.State()) {
//        BottomMenuReducer()
//      }
//
//      var body: some View {
//        Button("Present") { store.send(.showMenuButtonTapped, animation: .default) }
//          .frame(maxWidth: .infinity, maxHeight: .infinity)
//          .bottomMenu(store: self.$store.scope(state: \.bottomMenu, action: \.bottomMenu))
//      }
//    }
//
//    static var previews: some View {
//      Preview {
//        TestView()
//      }
//    }
//  }
#endif
