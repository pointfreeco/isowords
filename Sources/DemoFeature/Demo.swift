import ApiClient
import AudioPlayerClient
import Build
import ComposableArchitecture
import CubeCore
import DictionaryClient
import FeedbackGeneratorClient
import GameCore
import GameOverFeature
import LowPowerModeClient
import OnboardingFeature
import ServerConfig
import SharedModels
import StoreKit
import Styleguide
import SwiftUI
import TcaHelpers
import UIApplicationClient
import UserDefaultsClient

public struct DemoState: Equatable {
  var appStoreOverlayIsPresented: Bool
  var step: Step

  public init(
    appStoreOverlayIsPresented: Bool = false,
    step: Step = .onboarding(.init(presentationStyle: .demo))
  ) {
    self.appStoreOverlayIsPresented = appStoreOverlayIsPresented
    self.step = step
  }

  public enum Step: Equatable {
    case game(Game.State)
    case onboarding(Onboarding.State)
  }

  var game: Game.State? {
    get {
      guard case let .game(game) = self.step
      else { return nil }
      return game
    }
    set {
      guard
        let newValue = newValue,
        case .game = self.step
      else { return }
      self.step = .game(newValue)
    }
  }
}

public enum DemoAction: Equatable {
  case appStoreOverlay(isPresented: Bool)
  case fullVersionButtonTapped
  case game(Game.Action)
  case gameOverDelay
  case onAppear
  case onboarding(Onboarding.Action)
}

public struct DemoEnvironment {
  var apiClient: ApiClient
  var applicationClient: UIApplicationClient
  var audioPlayer: AudioPlayerClient
  var backgroundQueue: AnySchedulerOf<DispatchQueue>
  var build: Build
  var dictionary: DictionaryClient
  var feedbackGenerator: FeedbackGeneratorClient
  var lowPowerMode: LowPowerModeClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var mainRunLoop: AnySchedulerOf<RunLoop>
  var userDefaults: UserDefaultsClient

  public init(
    apiClient: ApiClient,
    applicationClient: UIApplicationClient,
    audioPlayer: AudioPlayerClient,
    backgroundQueue: AnySchedulerOf<DispatchQueue>,
    build: Build,
    dictionary: DictionaryClient,
    feedbackGenerator: FeedbackGeneratorClient,
    lowPowerMode: LowPowerModeClient,
    mainQueue: AnySchedulerOf<DispatchQueue>,
    mainRunLoop: AnySchedulerOf<RunLoop>,
    userDefaults: UserDefaultsClient
  ) {
    self.apiClient = apiClient
    self.applicationClient = applicationClient
    self.audioPlayer = audioPlayer
    self.backgroundQueue = backgroundQueue
    self.build = build
    self.dictionary = dictionary
    self.feedbackGenerator = feedbackGenerator
    self.lowPowerMode = lowPowerMode
    self.mainQueue = mainQueue
    self.mainRunLoop = mainRunLoop
    self.userDefaults = userDefaults
  }
}

public let demoReducer = Reducer<DemoState, DemoAction, DemoEnvironment>.combine(
  Reducer(
    Scope(state: \.step, action: .self) {
      EmptyReducer()
        .ifLet(
          state: /DemoState.Step.onboarding,
          action: /DemoAction.onboarding
        ) {
          Onboarding()
        }
    }
  ),

  Reducer(
    IntegratedGame(
      state: OptionalPath(\.game),
      action: /DemoAction.game,
      isHapticsEnabled: { _ in true }
    )
    .dependency(\.database, .noop)
    .dependency(\.fileClient, .noop)
    .dependency(\.gameCenter, .noop)
    .dependency(\.remoteNotifications, .noop)
    .dependency(\.serverConfig, .noop)
    .dependency(\.storeKit, .noop)
    .dependency(\.userDefaults, .noop)
    .dependency(\.userNotifications, .noop)
  ),

  .init { state, action, environment in
    switch action {
    case let .appStoreOverlay(isPresented: isPresented):
      state.appStoreOverlayIsPresented = isPresented
      return .none

    case .fullVersionButtonTapped:
      return .fireAndForget {
        _ = await environment.applicationClient.open(ServerConfig().appStoreUrl, [:])
      }

    case .game(.gameOver(.submitGameResponse(.success))):
      state.appStoreOverlayIsPresented = true
      return .none

    case .game:
      return .none

    case .gameOverDelay:
      state.appStoreOverlayIsPresented = true
      return .none

    case .onAppear:
      return .fireAndForget {
        await environment.audioPlayer.load(AudioPlayerClient.Sound.allCases)
      }

    case .onboarding(.delegate(.getStarted)):
      state.step = .game(
        .init(
          cubes: environment.dictionary.randomCubes(.en),
          gameContext: .solo,
          gameCurrentTime: environment.mainRunLoop.now.date,
          gameMode: .timed,
          gameStartTime: environment.mainRunLoop.now.date,
          isDemo: true
        )
      )
      return .none

    case .onboarding:
      return .none
    }
  }
)
.onChange(of: { $0.game?.gameOver != nil }) { _, _, _, environment in
  .task {
    try await environment.mainQueue.sleep(for: .seconds(2))
    return .gameOverDelay
  }
}

public struct DemoView: View {
  let store: Store<DemoState, DemoAction>
  @ObservedObject var viewStore: ViewStore<ViewState, DemoAction>

  struct ViewState: Equatable {
    let appStoreOverlayIsPresented: Bool
    let isGameOver: Bool

    init(state: DemoState) {
      self.appStoreOverlayIsPresented = state.appStoreOverlayIsPresented
      self.isGameOver = state.game?.gameOver != nil
    }
  }

  public init(
    store: Store<DemoState, DemoAction>
  ) {
    self.store = store
    self.viewStore = ViewStore(self.store.scope(state: ViewState.init(state:)))
  }

  public var body: some View {
    SwitchStore(self.store.scope(state: \.step)) {
      CaseLet(
        state: /DemoState.Step.onboarding,
        action: DemoAction.onboarding,
        then: {
          OnboardingView(store: $0)
            .onAppear { self.viewStore.send(.onAppear) }
        }
      )

      CaseLet(
        state: /DemoState.Step.game,
        action: DemoAction.game,
        then: { store in
          GameWrapper(
            content: GameView(
              content: CubeView(
                store: store.scope(
                  state: { CubeSceneView.ViewState(game: $0, nub: nil, settings: .init()) },
                  action: { CubeSceneView.ViewAction.to(gameAction: $0) }
                )
              ),
              isAnimationReduced: false,
              store: store
            ),
            isGameOver: self.viewStore.isGameOver,
            bannerAction: {
              self.viewStore.send(.fullVersionButtonTapped)
            }
          )
        }
      )
    }
    .appStoreOverlay(
      isPresented: self.viewStore.binding(
        get: \.appStoreOverlayIsPresented,
        send: DemoAction.appStoreOverlay(isPresented:)
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
        Button(action: { self.bannerAction() }) {
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
          .adaptivePadding([.top], .grid(2))
          .adaptivePadding([.bottom], .grid(4))
          .adaptivePadding([.horizontal], .grid(4))
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
