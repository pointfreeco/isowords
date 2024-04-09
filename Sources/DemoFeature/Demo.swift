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
  @ObservableState
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

  public enum Action {
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

    Reduce {
      state,
      action in
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
            //            cubes: self.randomCubes(.en),
            //            gameContext: .solo,
            gameCurrentTime: self.now,
            gameMode: .timed,
            gameStartTime: self.now,
            isDemo: true,
            puzzle: PuzzleState.init(
              cubes: self.randomCubes(.en),
              gameContext: .solo
            )
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
  @Bindable var store: StoreOf<Demo>

  public init(store: StoreOf<Demo>) {
    self.store = store
  }

  public var body: some View {
    Group {
      switch store.step {
      case .onboarding:
        if let store = store.scope(state: \.step.onboarding, action: \.onboarding) {
          OnboardingView(store: store)
            .onAppear { self.store.send(.onAppear) }
        }

      case .game:
        if let store = store.scope(state: \.step.game, action: \.game) {
          GameWrapper(
            content: GameView(
              content: CubeView(store: store.scope(state: \.cubeScene, action: \.cubeScene)),
              store: store
            ),
            isGameOver: self.store.isGameOver,
            bannerAction: {
              self.store.send(.fullVersionButtonTapped)
            }
          )
        }
      }
    }
    .appStoreOverlay(
      isPresented: $store.appStoreOverlayIsPresented.sending(\.appStoreOverlay)
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
