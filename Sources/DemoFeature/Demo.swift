import AudioPlayerClient
import ComposableArchitecture
import CubeCore
import GameCore
import OnboardingFeature
import ServerConfig
import StoreKit
import SwiftUI
import TcaHelpers

@Reducer
public struct Demo {
  public struct State: Equatable {
    var appStoreOverlayIsPresented: Bool
    var step: Step

    public init(
      appStoreOverlayIsPresented: Bool = false,
      step: Step = .onboarding(.init(presentationStyle: .demo))
    ) {
      self.appStoreOverlayIsPresented = appStoreOverlayIsPresented
      self.step = step
    }

    @CasePathable
    @dynamicMemberLookup
    public enum Step: Equatable {
      case game(Game.State)
      case onboarding(Onboarding.State)
    }

    var isGameOver: Bool {
      self.step.game?.destination.is(\.some.gameOver) == true
    }
  }

  public enum Action: Equatable {
    case appStoreOverlay(isPresented: Bool)
    case fullVersionButtonTapped
    case game(Game.Action)
    case gameOverDelay
    case onAppear
    case onboarding(Onboarding.Action)
  }

  @Dependency(\.audioPlayer.load) var loadSounds
  @Dependency(\.mainQueue) var mainQueue
  @Dependency(\.mainRunLoop.now.date) var now
  @Dependency(\.applicationClient.open) var openURL
  @Dependency(\.dictionary.randomCubes) var randomCubes

  public init() {}

  public var body: some ReducerOf<Self> {
    Scope(state: \.step, action: \.self) {
      Scope(state: \.onboarding, action: \.onboarding) {
        Onboarding()
      }
      Scope(state: \.game, action: \.game) {
        Game().transformDependency(\.self) {
          $0.database = .noop
          $0.fileClient = .noop
          $0.gameCenter = .noop
          $0.remoteNotifications = .noop
          $0.serverConfig = .noop
          $0.storeKit = .noop
          $0.userDefaults = .noop
          $0.userNotifications = .noop
        }
      }
    }
    .onChange(of: \.isGameOver) { _, _ in
      Reduce { _, _ in
        .run { send in
          try await self.mainQueue.sleep(for: .seconds(2))
          await send(.gameOverDelay)
        }
      }
    }

    Reduce { state, action in
      switch action {
      case let .appStoreOverlay(isPresented: isPresented):
        state.appStoreOverlayIsPresented = isPresented
        return .none

      case .fullVersionButtonTapped:
        return .run { _ in
          _ = await self.openURL(ServerConfig().appStoreUrl, [:])
        }

      case .game(.destination(.presented(.gameOver(.submitGameResponse(.success))))):
        state.appStoreOverlayIsPresented = true
        return .none

      case .game:
        return .none

      case .gameOverDelay:
        state.appStoreOverlayIsPresented = true
        return .none

      case .onAppear:
        return .run { _ in
          await self.loadSounds(AudioPlayerClient.Sound.allCases)
        }

      case .onboarding(.delegate(.getStarted)):
        state.step = .game(
          .init(
            cubes: self.randomCubes(.en),
            gameContext: .solo,
            gameCurrentTime: self.now,
            gameMode: .timed,
            gameStartTime: self.now,
            isDemo: true
          )
        )
        return .none

      case .onboarding:
        return .none
      }
    }
  }
}

public struct DemoView: View {
  let store: StoreOf<Demo>
  @ObservedObject var viewStore: ViewStore<ViewState, Demo.Action>

  struct ViewState: Equatable {
    let appStoreOverlayIsPresented: Bool
    let isGameOver: Bool

    init(state: Demo.State) {
      self.appStoreOverlayIsPresented = state.appStoreOverlayIsPresented
      self.isGameOver = state.isGameOver
    }
  }

  public init(
    store: StoreOf<Demo>
  ) {
    self.store = store
    self.viewStore = ViewStore(self.store, observe: ViewState.init)
  }

  public var body: some View {
    SwitchStore(self.store.scope(state: \.step, action: { $0 })) { step in
      switch step {
      case .onboarding:
        CaseLet(\Demo.State.Step.onboarding, action: Demo.Action.onboarding) {
          OnboardingView(store: $0)
            .onAppear { self.viewStore.send(.onAppear) }
        }

      case .game:
        CaseLet(\Demo.State.Step.game, action: Demo.Action.game) { store in
          GameWrapper(
            content: GameView(
              content: CubeView(
                store: store.scope(
                  state: { CubeSceneView.ViewState(game: $0, nub: nil) },
                  action: { CubeSceneView.ViewAction.to(gameAction: $0) }
                )
              ),
              store: store
            ),
            isGameOver: self.viewStore.isGameOver,
            bannerAction: {
              self.viewStore.send(.fullVersionButtonTapped)
            }
          )
        }
      }
    }
    .appStoreOverlay(
      isPresented: self.viewStore.binding(
        get: \.appStoreOverlayIsPresented,
        send: Demo.Action.appStoreOverlay(isPresented:)
      )
    ) {
      SKOverlay.AppClipConfiguration(position: .bottom)
    }
  }
}

struct GameWrapper<Content: View>: View {
  @Environment(\.colorScheme) var colorScheme
  let content: Content
  let isGameOver: Bool
  let bannerAction: () -> Void

  var body: some View {
    ZStack(alignment: .top) {
      self.content

      if !self.isGameOver {
        Button {
          self.bannerAction()
        } label: {
          HStack {
            Text("Having fun?")
              .foregroundColor(.isowordsRed)

            Spacer()

            Text("Get the full version!")
              .foregroundColor(Color.adaptiveWhite)
              .adaptiveFont(.matterMedium, size: 14)
              .padding(.horizontal, .grid(3))
              .padding(.vertical, .grid(2))
              .background(
                Capsule()
                  .fill(Color.isowordsRed)
              )
          }
          .adaptiveFont(.matterMedium, size: 18)
          .foregroundColor(.isowordsBlack)
          .adaptivePadding(.top, .grid(2))
          .adaptivePadding(.bottom, .grid(4))
          .adaptivePadding(.horizontal, .grid(4))
        }
        .frame(maxWidth: .infinity)
        .background(
          Color.black
            .opacity(self.colorScheme == .dark ? 1 : 0.04)
            .edgesIgnoringSafeArea(.top)
        )
        .transition(.offset(x: 0, y: 300))
      }
    }
  }
}

#if DEBUG
  import SwiftUIHelpers

  struct GameWrapperPreviews: PreviewProvider {
    static var previews: some View {
      Preview {
        GameWrapper(
          content: ScrollView {},
          isGameOver: false,
          bannerAction: {}
        )
      }
    }
  }
#endif
