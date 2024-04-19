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
  @Bindable var store: StoreOf<Game>
  var trayHeight: CGFloat { ActiveGamesView.height + (16 + self.adaptiveSize.padding) * 2 }

  public init(
    content: Content,
    store: StoreOf<Game>
  ) {
    self.content = content
    self.store = store
  }

  public var body: some View {
    GeometryReader { proxy in
      ZStack {
        ZStack(alignment: .top) {
          if store.isGameLoaded {
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
              if store.isNavVisible {
                GameNavView(store: store)
              } else {
                GameNavView(store: store)
                  .hidden()
              }
              GameHeaderView(store: store)
            }
            .screenEdgePadding(self.deviceState.isPad ? .horizontal : [])
            Spacer()
            GameFooterView(store: store)
              .padding(.bottom)
          }
          .ignoresSafeArea(.keyboard)

          if !store.selectedWordString.isEmpty {
            WordSubmitButton(
              store: store.scope(state: \.wordSubmitButtonFeature, action: \.wordSubmitButton)
            )
            .ignoresSafeArea()
            .transition(
              store.userSettings.enableReducedAnimation
                ? .opacity
                : .asymmetric(insertion: .offset(y: 50), removal: .offset(y: 50))
                  .combined(with: .opacity)
            )
          }

          ActiveGamesView(
            store: store.scope(state: \.activeGames, action: \.activeGames),
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
          .opacity(store.isTrayVisible ? 1 : 0)
          .offset(y: -self.trayHeight)
        }
        .offset(y: store.isTrayVisible ? self.trayHeight : 0)
        .zIndex(0)

        if let store = store.scope(
          state: \.destination?.gameOver, action: \.destination.gameOver.presented
        ) {
          GameOverView(store: store)
            .background(Color.adaptiveWhite.ignoresSafeArea())
            .transition(
              .asymmetric(
                insertion: AnyTransition.opacity.animation(.linear(duration: 1)),
                removal: .game
              )
            )
            .zIndex(1)
        } else if let store = store.scope(
          state: \.destination?.upgradeInterstitial,
          action: \.destination.upgradeInterstitial.presented
        ) {
          UpgradeInterstitialView(store: store)
            .transition(.opacity)
            .zIndex(2)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background {
        if !store.userSettings.enableReducedAnimation {
          BloomBackground(
            size: proxy.size,
            word: store.selectedWordString
          )
        }
      }
      .background(
        Color(self.colorScheme == .dark ? .hex(0x111111) : .white)
          .ignoresSafeArea()
      )
      .bottomMenu($store.scope(state: \.destination?.bottomMenu, action: \.destination.bottomMenu))
      .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
      .sheet(
        item: $store.scope(state: \.destination?.settings, action: \.destination.settings)
      ) { store in
        NavigationStack {
          SettingsView(store: store, navPresentationStyle: .modal)
        }
      }
    }
    .task { await store.send(.task).finish() }
  }
}
