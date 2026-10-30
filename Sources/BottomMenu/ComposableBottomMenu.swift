import ComposableArchitecture
import SwiftUI

@Feature
public struct BottomMenuPrompt<MenuAction>: Prompt {
  public typealias Action = MenuAction

  public struct State {
    public var buttons: [Button]
    public var footerButton: Button?
    public var message: Text?
    public var title: Text

    public init(
      title: Text,
      message: Text? = nil,
      buttons: [Button] = [],
      footerButton: Button? = nil
    ) {
      self.buttons = buttons
      self.footerButton = footerButton
      self.message = message
      self.title = title
    }

    public struct Button {
      public let action: ButtonAction?
      public let icon: Image
      public let title: Text

      public init(
        title: Text,
        icon: Image,
        action: ButtonAction? = nil
      ) {
        self.action = action
        self.icon = icon
        self.title = title
      }
    }

    public struct ButtonAction {
      public let action: Action
      fileprivate let animation: Animation

      fileprivate enum Animation {
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

  public init() {}
}

public typealias BottomMenuState<Action> = BottomMenuPrompt<Action>.State

extension View {
  public func bottomMenu<MenuAction>(
    _ item: Binding<Store<BottomMenuState<MenuAction>, MenuAction>?>
  ) -> some View {
    let store = item.wrappedValue
    let state = store?.state
    return self.bottomMenu(
      item: Binding(
        get: {
          state?.converted(
            send: { store?.send($0) },
            sendWithAnimation: { action, animation in
              withAnimation(animation) { _ = store?.send(action) }
            }
          )
        },
        set: {
          if $0 == nil {
            item.transaction($1).wrappedValue = nil
          }
        }
      )
    )
  }
}

extension BottomMenuPrompt.State {
  fileprivate func converted(
    send: @escaping (MenuAction) -> Void,
    sendWithAnimation: @escaping (MenuAction, Animation?) -> Void
  ) -> BottomMenu {
    .init(
      title: self.title,
      message: self.message,
      buttons: self.buttons.map { $0.converted(send: send, sendWithAnimation: sendWithAnimation) },
      footerButton: self.footerButton.map {
        $0.converted(send: send, sendWithAnimation: sendWithAnimation)
      }
    )
  }
}

extension BottomMenuPrompt.State.Button {
  fileprivate func converted(
    send: @escaping (MenuAction) -> Void,
    sendWithAnimation: @escaping (MenuAction, Animation?) -> Void
  ) -> BottomMenu.Button {
    .init(
      title: self.title,
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
  import SwiftUIHelpers

  @Feature
  private struct BottomMenuPreview {
    @Feature enum Destination {
      case bottomMenu(BottomMenuPrompt<Menu>)
    }

    enum Menu {
      case endGameButtonTapped
      case mainMenuButtonTapped
      case settingsButtonTapped
    }

    struct State {
      var destination: Destination.State?
    }

    enum Action {
      case destination(Destination.Action)
      case showMenuButtonTapped
    }

    var body: some Feature {
      Update { state, action in
        switch action {
        case .destination:
          break
        case .showMenuButtonTapped:
          state.destination = .bottomMenu(
            BottomMenuState(
              title: Text("vs mbrandonw"),
              buttons: [
                .init(
                  title: Text("Main menu"),
                  icon: Image(systemName: "flag"),
                  action: .init(action: .mainMenuButtonTapped)
                ),
                .init(
                  title: Text("End game"),
                  icon: Image(systemName: "flag"),
                  action: .init(action: .endGameButtonTapped, animation: .default)
                ),
              ],
              footerButton: .init(
                title: Text("Settings"),
                icon: Image(systemName: "gear"),
                action: .init(action: .settingsButtonTapped)
              )
            )
          )
        }
      }
      .ifLet(\.destination) {
        Destination.body
      }
    }
  }

  struct BottomMenu_TCA_Previews: PreviewProvider {
    struct TestView: View {
      @Bindable fileprivate var store = Store(initialState: BottomMenuPreview.State()) {
        BottomMenuPreview()
      }

      var body: some View {
        Button("Present") { withAnimation { _ = store.send(.showMenuButtonTapped) } }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .bottomMenu($store.scope(\.destination).bottomMenu)
      }
    }

    static var previews: some View {
      Preview {
        TestView()
      }
    }
  }
#endif
