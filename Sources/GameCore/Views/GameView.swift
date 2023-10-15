import ActiveGamesFeature
import Bloom
import ComposableArchitecture
import GameOverFeature
import SettingsFeature
import SwiftUI
import UpgradeInterstitialFeature

extension AnyTransition {
  public static let game = move(edge: .bottom)
}

public struct GameView<Content>: View where Content: View {
  @Environment(\.adaptiveSize) var adaptiveSize
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.deviceState) var deviceState
  let content: Content
  let store: StoreOf<Game>
  var trayHeight: CGFloat { ActiveGamesView.height + (16 + self.adaptiveSize.padding) * 2 }
  @ObservedObject var viewStore: ViewStore<ViewState, Game.Action>

  struct ViewState: Equatable {
    let isAnimationReduced: Bool
    let isDailyChallenge: Bool
    let isGameLoaded: Bool
    let isNavVisible: Bool
    let isTrayVisible: Bool
    let selectedWordString: String

    init(state: Game.State) {
      self.isAnimationReduced = state.isAnimationReduced
      self.isDailyChallenge = state.gameContext.is(\.dailyChallenge)
      self.isGameLoaded = state.isGameLoaded
      self.isNavVisible = state.isNavVisible
      self.isTrayVisible = state.isTrayVisible
      self.selectedWordString = state.selectedWordString
    }
  }

  public init(
    content: Content,
    store: StoreOf<Game>
  ) {
    self.content = content
    self.store = store
    self.viewStore = ViewStore(self.store, observe: ViewState.init)
  }

  public var body: some View {
    GeometryReader { proxy in
      ZStack {
        ZStack(alignment: .top) {
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
            GameFooterView(store: self.store)
              .padding(.bottom)
          }
          .ignoresSafeArea(.keyboard)

          if !self.viewStore.selectedWordString.isEmpty {
            WordSubmitButton(
              store: self.store.scope(
                state: \.wordSubmitButtonFeature,
                action: { .wordSubmitButton($0) }
              )
            )
            .ignoresSafeArea()
            .transition(
              viewStore.isAnimationReduced
                ? .opacity
                : AnyTransition
                  .asymmetric(insertion: .offset(y: 50), removal: .offset(y: 50))
                  .combined(with: .opacity)
            )
          }

          ActiveGamesView(
            store: self.store.scope(state: \.activeGames, action: { .activeGames($0) }),
            showMenuItems: false
          )
          .adaptivePadding(.vertical, 8)
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
        .zIndex(0)

        IfLetStore(
          self.store.scope(state: \.$destination, action: { .destination($0) }),
          state: \.gameOver,
          action: { .gameOver($0) },
          then: GameOverView.init(store:)
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
          self.store.scope(state: \.$destination, action: { .destination($0) }),
          state: \.upgradeInterstitial,
          action: { .upgradeInterstitial($0) }
        ) { store in
          UpgradeInterstitialView(store: store)
            .transition(.opacity)
        }
        .zIndex(2)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(
        viewStore.isAnimationReduced
          ? nil
          : BloomBackground(
            size: proxy.size,
            store: self.store
              .scope(
                state: {
                  BloomBackground.ViewState(
                    bloomCount: $0.selectedWord.count,
                    word: $0.selectedWordString
                  )
                },
                action: absurd
              )
          )
      )
      .background(
        Color(self.colorScheme == .dark ? .hex(0x111111) : .white)
          .ignoresSafeArea()
      )
      .bottomMenu(
        store: self.store.scope(state: \.$destination, action: { .destination($0) }),
        state: \.bottomMenu,
        action: { .bottomMenu($0) }
      )
      .alert(
        store: self.store.scope(state: \.$destination, action: { .destination($0) }),
        state: \.alert,
        action: { .alert($0) }
      )
      .sheet(
        store: self.store.scope(state: \.$destination, action: { .destination($0) }),
        state: \.settings,
        action: { .settings($0) }
      ) { store in
        NavigationStack {
          SettingsView(store: store, navPresentationStyle: .modal)
        }
      }
    }
    .task { await self.viewStore.send(.task).finish() }
  }
}

private func absurd<A>(_: Never) -> A {}
