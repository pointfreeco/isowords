import AudioPlayerClient
import Bloom
import ComposableArchitecture
import CubeCore
import GameCore
import SharedModels
import SwiftUI
import UIApplicationClient

@Reducer
public struct Trailer {
  public struct State: Equatable {
    var game: Game.State
    @BindingState var nub: CubeSceneView.ViewState.NubState
    @BindingState var opacity: Double

    public init(
      game: Game.State,
      nub: CubeSceneView.ViewState.NubState = .init(),
      opacity: Double = 0
    ) {
      self.game = game
      self.nub = nub
      self.opacity = opacity
    }

    public init() {
      self = .init(
        game: .init(
          cubes: .trailer,
          gameContext: .solo,
          gameCurrentTime: .init(),
          gameMode: .unlimited,
          gameStartTime: .init(),
          moves: []
        )
      )
    }

    fileprivate var cubeScene: CubeSceneView.ViewState {
      .init(game: self.game, nub: self.nub)
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case game(Game.Action)
    case task
  }

  @Dependency(\.audioPlayer) var audioPlayer
  @Dependency(\.mainQueue) var mainQueue

  public init() {}

  public var body: some ReducerOf<Self> {
    Scope(state: \.game, action: \.game) {
      Game().transformDependency(\.self) {
        $0.apiClient = .noop
        $0.applicationClient = .noop
        $0.audioPlayer = self.audioPlayer
          .filteredSounds(doNotInclude: AudioPlayerClient.Sound.allValidWords)
        $0.build = .noop
        $0.database = .noop
        $0.feedbackGenerator = .noop
        $0.fileClient = .noop
        $0.gameCenter = .noop
        $0.lowPowerMode = .false
        $0.remoteNotifications = .noop
        $0.serverConfig = .noop
        $0.storeKit = .noop
        $0.userDefaults = .noop
        $0.userNotifications = .noop
      }
    }

    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .game:
        return .none

      case .task:
        return .run { [nub = state.nub] send in
          var nub = nub
          await self.audioPlayer.load(AudioPlayerClient.Sound.allCases)

          // Play trailer music
          await self.audioPlayer.play(.onboardingBgMusic)

          // Fade the cube in after a second
          await send(.set(\.$opacity, 1), animation: .easeInOut(duration: fadeInDuration))
          try await self.mainQueue.sleep(for: firstWordDelay)

          // Play each word
          for word in replayableWords {
            // Play each character in the word
            for (characterIndex, character) in word.enumerated() {
              let face = IndexedCubeFace(index: character.index, side: character.side)

              // Move the nub to the face being played
              nub.location = .face(face)
              await send(
                .set(\.$nub, nub),
                animateWithDuration: moveNubToFaceDuration,
                options: .curveEaseInOut
              )
              try await self.mainQueue.sleep(
                for: moveNubDelay(characterIndex: characterIndex)
              )

              try await self.mainQueue.sleep(
                for: .seconds(
                  .random(in: (0.3 * moveNubToFaceDuration)...(0.7 * moveNubToFaceDuration)))
              )
              // Press the nub on the first character
              nub.isPressed = true
              if characterIndex == 0 {
                await send(.set(\.$nub, nub), animateWithDuration: 0.3)
              }
              // Select the cube face
              await send(.game(.tap(.began, face)), animation: .default)
            }

            // Release the  nub when the last character is played
            nub.isPressed = false
            await send(.set(\.$nub, nub), animateWithDuration: 0.3)

            // Move the nub to the submit button
            try await self.mainQueue.sleep(for: .seconds(0.3))

            nub.location = .submitButton
            await send(
              .set(\.$nub, nub),
              animateWithDuration: moveNubToSubmitButtonDuration,
              options: .curveEaseInOut
            )

            // Press the nub
            try await self.mainQueue.sleep(
              for: .seconds(
                .random(
                  in:
                    moveNubToSubmitButtonDuration...(moveNubToSubmitButtonDuration
                    + submitHestitationDuration)
                )
              )
            )

            // Submit the word
            try await self.mainQueue.sleep(for: .seconds(0.1))
            await withThrowingTaskGroup(of: Void.self) { group in
              group.addTask { [nub] in
                var nub = nub
                nub.isPressed = true
                await send(.set(\.$nub, nub), animateWithDuration: 0.3)
              }
              group.addTask { [nub] in
                var nub = nub
                try await self.mainQueue.sleep(for: .seconds(0.2))
                await send(.game(.submitButtonTapped(reaction: nil)))
                try await self.mainQueue.sleep(for: .seconds(0.3))
                nub.isPressed = false
                await send(.set(\.$nub, nub), animateWithDuration: 0.3)
              }
            }
          }

          // Move the nub off screen once all words have been played
          try await self.mainQueue.sleep(for: .seconds(0.3))
          nub.location = .offScreenBottom
          await send(
            .set(\.$nub, nub),
            animateWithDuration: moveNubOffScreenDuration,
            options: .curveEaseInOut
          )

          await send(.set(\.$opacity, 0), animation: .linear(duration: moveNubOffScreenDuration))
        }
      }
    }
  }
}

public struct TrailerView: View {
  let store: StoreOf<Trailer>
  @ObservedObject var viewStore: ViewStore<ViewState, Trailer.Action>
  @Environment(\.deviceState) var deviceState

  struct ViewState: Equatable {
    let opacity: Double
    let selectedWordHasAlreadyBeenPlayed: Bool
    let selectedWordIsValid: Bool
    let selectedWordScore: Int?
    let selectedWordString: String

    init(state: Trailer.State) {
      self.opacity = state.opacity
      self.selectedWordHasAlreadyBeenPlayed = state.game.selectedWordHasAlreadyBeenPlayed
      self.selectedWordIsValid = state.game.selectedWordIsValid
      self.selectedWordScore = self.selectedWordIsValid ? state.game.selectedWordScore : nil
      self.selectedWordString = state.game.selectedWordString
    }
  }

  public init(store: StoreOf<Trailer>) {
    self.store = store
    self.viewStore = ViewStore(self.store, observe: ViewState.init)
  }

  public var body: some View {
    GeometryReader { proxy in
      ZStack {
        VStack {
          if !self.viewStore.selectedWordString.isEmpty {
            (Text(self.viewStore.selectedWordString)
              + self.scoreText
              .baselineOffset(
                (self.deviceState.idiom == .pad ? 2 : 1) * 16
              )
              .font(
                .custom(
                  .matterMedium,
                  size: (self.deviceState.idiom == .pad ? 2 : 1) * 20
                )
              ))
              .adaptiveFont(
                .matterSemiBold,
                size: (self.deviceState.idiom == .pad ? 2 : 1) * 32
              )
              .opacity(self.viewStore.selectedWordIsValid ? 1 : 0.5)
              .allowsTightening(true)
              .minimumScaleFactor(0.2)
              .lineLimit(1)
              .transition(.opacity)
              .animation(nil, value: self.viewStore.selectedWordString)
          }

          Spacer()

          if !self.viewStore.selectedWordString.isEmpty {
            WordSubmitButton(
              store: self.store.scope(
                state: \.game.wordSubmitButtonFeature,
                action: \.game.wordSubmitButton
              )
            )
            .transition(
              AnyTransition
                .asymmetric(insertion: .offset(y: 50), removal: .offset(y: 50))
                .combined(with: .opacity)
            )
            .offset(y: .grid(6))
          }

          WordListView(
            isLeftToRight: true,
            store: self.store.scope(state: \.game, action: \.game)
          )
        }
        .adaptivePadding(.top, .grid(18))
        .adaptivePadding(.bottom, .grid(2))

        CubeView(store: self.store.scope(state: \.cubeScene, action: \.game.cubeScene))
          .adaptivePadding(
            self.deviceState.idiom == .pad ? .horizontal : [],
            .grid(30)
          )
      }
      .background(
        BloomBackground(
          size: proxy.size,
          store: self.store
            .scope(
              state: {
                BloomBackground.ViewState(
                  bloomCount: $0.game.selectedWord.count,
                  word: $0.game.selectedWordString
                )
              },
              action: absurd
            )
        )
      )
    }
    .padding(
      self.deviceState.idiom == .pad ? .vertical : [],
      .grid(15)
    )
    .opacity(self.viewStore.opacity)
    .task { await self.viewStore.send(.task).finish() }
  }

  var scoreText: Text {
    self.viewStore.selectedWordScore.map {
      Text(" \($0)")
    } ?? Text("")
  }
}

private func moveNubDelay(characterIndex: Int) -> DispatchQueue.SchedulerTimeType.Stride {
  if characterIndex == 0 {
    return firstCharacterDelay
  } else {
    return 0
  }
}

private let firstCharacterDelay: DispatchQueue.SchedulerTimeType.Stride = 0.3
private let firstWordDelay: DispatchQueue.SchedulerTimeType.Stride = 1.5
private let moveNubToFaceDuration = 0.45
private let moveNubToSubmitButtonDuration = 0.4
private let moveNubOffScreenDuration = 0.5
private let fadeInDuration = 0.3
private let fadeOutDuration = 0.3
private let submitPressDuration = 0.05
private let submitHestitationDuration = 0.15

private func absurd<A>(_: Never) -> A {}
