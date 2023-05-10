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
extension BottomMenuState: _EphemeralState {}

extension View {
  public func bottomMenu<DestinationState, DestinationAction, MenuAction: Equatable>(
    store: Store<PresentationState<DestinationState>, PresentationAction<DestinationAction>>,
    state toMenuState: @escaping (DestinationState) -> BottomMenuState<MenuAction>?,
    action fromMenuAction: @escaping (MenuAction) -> DestinationAction
  ) -> some View {
    WithViewStore(
      store,
      observe: { $0 },
      removeDuplicates: {
        ($0.wrappedValue.flatMap(toMenuState) != nil)
          == ($1.wrappedValue.flatMap(toMenuState) != nil)
      }
    ) { viewStore in
      self.bottomMenu(
        item: Binding(
          get: {
            viewStore.wrappedValue.flatMap(toMenuState)?.converted(
              send: { viewStore.send(.presented(fromMenuAction($0))) },
              sendWithAnimation: { viewStore.send(.presented(fromMenuAction($0)), animation: $1) }
            )
          },
          set: { state, transaction in
            withAnimation(transaction.disablesAnimations ? nil : transaction.animation) {
              if state == nil {
                viewStore.send(.dismiss)
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

//#if DEBUG
//  import ComposableArchitecture
//  import SwiftUIHelpers
//
//  private struct BottomMenuReducer: ReducerProtocol {
//    typealias State = BottomMenuState<Action>?
//
//    enum Action {
//      case show
//      case dismiss
//    }
//
//    func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
//      switch action {
//      case .show:
//        state = .init(
//          title: .init("vs mbrandonw"),
//          buttons: [
//            .init(
//              title: .init("Main menu"),
//              icon: Image(systemName: "flag")
//            ),
//            .init(
//              title: .init("End game"),
//              icon: Image(systemName: "flag")
//            ),
//          ],
//          footerButton: .init(
//            title: .init("Settings"),
//            icon: Image(systemName: "gear")
//          ),
//          onDismiss: .init(action: .dismiss, animation: .default)
//        )
//        return .none
//      case .dismiss:
//        state = nil
//        return .none
//      }
//    }
//  }
//
//  struct BottomMenu_TCA_Previews: PreviewProvider {
//    struct TestView: View {
//      private let store = Store(
//        initialState: nil,
//        reducer: BottomMenuReducer()
//      )
//
//      var body: some View {
//        WithViewStore(self.store.stateless) { viewStore in
//          Button("Present") { viewStore.send(.show, animation: .default) }
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
//            .bottomMenu(self.store)
//        }
//      }
//    }
//
//    static var previews: some View {
//      Preview {
//        TestView()
//      }
//    }
//  }
//#endif
