import AudioPlayerClient
import ComposableArchitecture
import CubeCore
import Dependencies
import GameCore
import GameOverFeature
import OnboardingFeature
import ServerConfig
import SharedModels
import StoreKit
import SwiftUI
import TcaHelpers

@Feature
public struct Demo {
  @Feature public enum Step {
    case game(Game)
    case onboarding(Onboarding)
  }

  public struct State {
    @DebugSnapshotTracked var appStoreOverlayIsPresented: Bool
    @DebugSnapshotTracked var step: Step.State

    public init(
      appStoreOverlayIsPresented: Bool = false,
      step: Step.State = .onboarding(.init(presentationStyle: .demo))
    ) {
      self.appStoreOverlayIsPresented = appStoreOverlayIsPresented
      self.step = step
    }

    var isGameOver: Bool {
      guard case let .game(game) = step else { return false }
      return game.destination.is(\.some.gameOver)
    }
  }

  public enum Action {
    case fullVersionButtonTapped
  }

  @Dependency(\.audioPlayer.load) var loadSounds
  @FeatureEnvironment(\.continuousClock) var clock
  @FeatureEnvironment(\.date.now) var now
  @Dependency(\.applicationClient.open) var openURL
  @Dependency(\.dictionary.randomCubes) var randomCubes

  public init() {}

  public var body: some Feature {
    Update { state, action in
      switch action {
      case .fullVersionButtonTapped:
        store.addTask {
          _ = await openURL(ServerConfig().appStoreUrl, [:])
        }
      }
    }
    Scope(\.step) {
      Update { _, _ in }
        .ifCaseLet(\.onboarding) {
          Onboarding()
        }
        .ifCaseLet(\.game) {
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
    .onEvent(Onboarding.GetStarted.self) { _, state in
      state.step = .game(
        Game.State(
          cubes: randomCubes(.en),
          gameContext: .solo,
          gameCurrentTime: now,
          gameMode: .timed,
          gameStartTime: now,
          isDemo: true
        )
      )
    }
    .onEvent(GameOver.Event.self) { event, state -> FeatureEventPropagation in
      guard case .gameSubmitted = event else { return .continue }
      state.appStoreOverlayIsPresented = true
      return .stop
    }
    .onChange(of: store.isGameOver) { _, _, _ in
      store.addTask {
        try await clock.sleep(for: .seconds(2))
        try store.modify { $0.appStoreOverlayIsPresented = true }
      }
    }
    .onMount { _ in
      store.addTask {
        await loadSounds(AudioPlayerClient.Sound.allCases)
      }
    }
  }
}

public struct DemoView: View {
  @Bindable var store: StoreOf<Demo>

  public init(store: StoreOf<Demo>) {
    self.store = store
  }

  public var body: some View {
    Group {
      switch store.scope(\.step) {
      case let .onboarding(store):
        OnboardingView(store: store)

      case let .game(store):
        GameWrapper(
          content: GameView(
            content: CubeView(
              store: store,
              state: \.cubeScene,
              action: CubeSceneView.ViewAction.to(gameAction:)
            ),
            store: store
          ),
          isGameOver: store.isGameOver,
          bannerAction: {
            self.store.send(.fullVersionButtonTapped)
          }
        )
      }
    }
    .appStoreOverlay(isPresented: $store.appStoreOverlayIsPresented) {
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
      content

      if !isGameOver {
        Button {
          bannerAction()
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
            .opacity(colorScheme == .dark ? 1 : 0.04)
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
