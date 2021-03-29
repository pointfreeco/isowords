import ActiveGamesFeature
import BottomMenu
import ComposableArchitecture
import GameOverFeature
import Overture
import SharedModels
import Styleguide
import SwiftUI
import UIApplicationClient
import UpgradeInterstitialFeature

extension AnyTransition {
  public static let game = move(edge: .bottom)
}

public struct GameView<Content>: View where Content: View {
  @Environment(\.adaptiveSize) var adaptiveSize
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.deviceState) var deviceState
  let content: Content
  let isAnimationReduced: Bool
  let store: Store<GameState, GameAction>
  var trayHeight: CGFloat { ActiveGamesView.height + (16 + self.adaptiveSize.padding) * 2 }
  @ObservedObject var viewStore: ViewStore<ViewState, GameAction>

  struct ViewState: Equatable {
    let isDailyChallenge: Bool
    let isGameLoaded: Bool
    let isNavVisible: Bool
    let isTrayVisible: Bool
    let selectedWordString: String

    init(state: GameState) {
      self.isDailyChallenge = state.dailyChallengeId != nil
      self.isGameLoaded = state.isGameLoaded
      self.isNavVisible = state.isNavVisible
      self.isTrayVisible = state.isTrayVisible
      self.selectedWordString = state.selectedWordString
    }
  }

  public init(
    content: Content,
    isAnimationReduced: Bool,
    store: Store<GameState, GameAction>
  ) {
    self.content = content
    self.isAnimationReduced = isAnimationReduced
    self.store = store
    self.viewStore = ViewStore(self.store.scope(state: ViewState.init(state:)))
  }

  public var body: some View {
    GeometryReader { proxy in
      ZStack {
        IfLetStore(
          self.store.scope(state: \.gameOver, action: GameAction.gameOver),
          then: GameOverView.init(store:),
          else: ZStack(alignment: .top) {
            if self.viewStore.isGameLoaded {
              self.content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .ignoresSafeArea()
                .transition(
                  .asymmetric(
                    insertion: AnyTransition.opacity.animation(Animation.default.delay(1.5)),
                    removal: .game
                  )
                )
                .adaptivePadding(self.deviceState.isPad ? .horizontal : [], .grid(30))
            } else {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .adaptiveBlack))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(AnyTransition.opacity.animation(Animation.default.delay(1.5)))
            }

            VStack {
              Group {
                if self.viewStore.isNavVisible {
                  GameNavView(store: self.store)
                } else {
                  GameNavView(store: self.store)
                    .hidden()
                }
                GameHeaderView(store: self.store)
              }
              .screenEdgePadding(self.deviceState.isPad ? .horizontal : [])
              Spacer()
              GameFooterView(isAnimationReduced: self.isAnimationReduced, store: self.store)
                .padding(.bottom)
            }
            .ignoresSafeArea(.keyboard)

            if !self.viewStore.selectedWordString.isEmpty {
              WordSubmitButton(
                store: self.store.scope(
                  state: \.wordSubmitButtonFeature,
                  action: GameAction.wordSubmitButton
                )
              )
              .ignoresSafeArea()
              .transition(
                self.isAnimationReduced
                  ? .opacity
                  : AnyTransition
                  .asymmetric(insertion: .offset(y: 50), removal: .offset(y: 50))
                  .combined(with: .opacity)
              )
            }

            ActiveGamesView(
              store: self.store.scope(state: \.activeGames, action: GameAction.activeGames),
              showMenuItems: false
            )
            .adaptivePadding([.top, .bottom], 8)
            .frame(maxWidth: .infinity, minHeight: ActiveGamesView.height)
            .background(
              LinearGradient(
                gradient: Gradient(
                  stops: [
                    .init(color: Color.adaptiveBlack.opacity(0.1), location: 0),
                    .init(color: Color.adaptiveBlack.opacity(0), location: 0.2),
                  ]
                ),
                startPoint: .bottom,
                endPoint: .top
              )
            )
            .fixedSize(horizontal: false, vertical: true)
            .opacity(self.viewStore.isTrayVisible ? 1 : 0)
            .offset(y: -self.trayHeight)
          }
          .offset(y: self.viewStore.isTrayVisible ? self.trayHeight : 0)
          .onAppear { self.viewStore.send(.onAppear) }
          .zIndex(0)
        )
        .background(Color.adaptiveWhite.ignoresSafeArea())
        .transition(
          .asymmetric(
            insertion: AnyTransition.opacity.animation(.linear(duration: 1)),
            removal: .game
          )
        )
        .zIndex(1)

        IfLetStore(
          self.store.scope(
            state: \.upgradeInterstitial,
            action: GameAction.upgradeInterstitial
          ),
          then: { store in
            UpgradeInterstitialView(store: store)
              .transition(.opacity)
          }
        )
        .zIndex(2)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(
        self.isAnimationReduced
          ? nil
          : BloomBackground(size: proxy.size, store: self.store)
      )
      .background(
        Color(self.colorScheme == .dark ? .hex(0x111111) : .white)
          .ignoresSafeArea()
      )
      .bottomMenu(self.store.scope(state: \.bottomMenu))
      .alert(self.store.scope(state: \.alert, action: GameAction.alert))
    }
  }
}
