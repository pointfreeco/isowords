import AudioPlayerClient
import Bloom
import Combine
import ComposableArchitecture
import CubeCore
import DictionaryClient
import GameCore
import SharedModels
import SwiftUI

public struct TrailerState: Equatable {
  var game: GameState
  @BindableState var nub: CubeSceneView.ViewState.NubState
  @BindableState var opacity: Double

  public init(
    game: GameState,
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
}

public enum TrailerAction: BindableAction, Equatable {
  case delayedOnAppear
  case game(GameAction)
  case binding(BindingAction<TrailerState>)
  case onAppear
}

public struct TrailerEnvironment {
  var audioPlayer: AudioPlayerClient
  var backgroundQueue: AnySchedulerOf<DispatchQueue>
  var dictionary: DictionaryClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var mainRunLoop: AnySchedulerOf<RunLoop>

  public init(
    audioPlayer: AudioPlayerClient,
    backgroundQueue: AnySchedulerOf<DispatchQueue>,
    dictionary: DictionaryClient,
    mainQueue: AnySchedulerOf<DispatchQueue>,
    mainRunLoop: AnySchedulerOf<RunLoop>
  ) {
    self.audioPlayer = audioPlayer.filteredSounds(
      doNotInclude: AudioPlayerClient.Sound.allValidWords
    )
    self.backgroundQueue = backgroundQueue
    self.dictionary = dictionary
    self.mainQueue = mainQueue
    self.mainRunLoop = mainRunLoop
  }
}

public let trailerReducer = Reducer<TrailerState, TrailerAction, TrailerEnvironment>.combine(
  gameReducer(
    state: \TrailerState.game,
    action: /TrailerAction.game,
    environment: {
      GameEnvironment(
        apiClient: .noop,
        applicationClient: .noop,
        audioPlayer: $0.audioPlayer,
        backgroundQueue: $0.backgroundQueue,
        build: .noop,
        database: .noop,
        dictionary: $0.dictionary,
        feedbackGenerator: .noop,
        fileClient: .noop,
        gameCenter: .noop,
        lowPowerMode: .false,
        mainQueue: $0.mainQueue,
        mainRunLoop: $0.mainRunLoop,
        remoteNotifications: .noop,
        serverConfig: .noop,
        setUserInterfaceStyle: { _ in },
        storeKit: .noop,
        userDefaults: .noop,
        userNotifications: .noop
      )
    },
    isHapticsEnabled: { _ in true }
  ),

  Reducer { state, action, environment in
    switch action {
    case .binding:
      return .none

    case .delayedOnAppear:
      state.opacity = 1

      var effects: [Effect<TrailerAction, Never>] = [
        environment.audioPlayer.play(.onboardingBgMusic)
          .fireAndForget()
      ]

      // Play each word
      for (wordIndex, word) in replayableWords.enumerated() {
        // Play each character in the word
        for (characterIndex, character) in word.enumerated() {
          let face = IndexedCubeFace(index: character.index, side: character.side)

          // Move the nub to the face being played
          effects.append(
            Effect(value: .set(\.$nub.location, .face(face)))
              .delay(
                for: moveNubDelay(wordIndex: wordIndex, characterIndex: characterIndex),
                scheduler: environment.mainQueue
                  .animate(withDuration: moveNubToFaceDuration, options: .curveEaseInOut)
              )
              .eraseToEffect()
          )
          effects.append(
            Effect.merge(
              // Press the nub on the first character
              characterIndex == 0 ? Effect(value: .set(\.$nub.isPressed, true)) : .none,
              // Tap on each face in the word being played
              Effect(value: .game(.tap(.began, face)))
            )
            .delay(
              for: .seconds(
                characterIndex == 0
                  ? moveNubToFaceDuration
                  : .random(in: (0.3 * moveNubToFaceDuration)...(0.7 * moveNubToFaceDuration))
              ),
              scheduler: environment.mainQueue.animation()
            )
            .eraseToEffect()
          )
        }

        // Release the  nub when the last character is played
        effects.append(
          Effect(value: .set(\.$nub.isPressed, false))
            .receive(on: environment.mainQueue.animate(withDuration: 0.3))
            .eraseToEffect()
        )
        // Move the nub to the submit button
        effects.append(
          Effect(value: .set(\.$nub.location, .submitButton))
            .delay(
              for: 0.2,
              scheduler: environment.mainQueue
                .animate(withDuration: moveNubToSubmitButtonDuration, options: .curveEaseInOut)
            )
            .eraseToEffect()
        )
        // Press the nub
        effects.append(
          Effect(value: .set(\.$nub.isPressed, true))
            .delay(
              for: .seconds(
                .random(
                  in:
                    moveNubToSubmitButtonDuration...(moveNubToSubmitButtonDuration
                    + submitHestitationDuration)
                )
              ),
              scheduler: environment.mainQueue.animation()
            )
            .eraseToEffect()
        )
        // Submit the word
        effects.append(
          Effect(value: .game(.submitButtonTapped(reaction: nil)))
        )
        // Release the nub
        effects.append(
          Effect(value: .set(\.$nub.isPressed, false))
            .delay(
              for: .seconds(submitPressDuration),
              scheduler: environment.mainQueue.animate(withDuration: 0.3)
            )
            .eraseToEffect()
        )
      }

      // Move the nub off screen once all words have been played
      effects.append(
        Effect(value: .set(\.$nub.location, .offScreenBottom))
          .delay(for: .seconds(0.3), scheduler: environment.mainQueue)
          .receive(
            on: environment.mainQueue
              .animate(withDuration: moveNubOffScreenDuration, options: .curveEaseInOut)
          )
          .eraseToEffect()
      )
      // Fade the scene out
      effects.append(
        Effect(value: .set(\.$opacity, 0))
          .receive(on: environment.mainQueue.animation(.linear(duration: moveNubOffScreenDuration)))
          .eraseToEffect()
      )

      return .concatenate(effects)

    case .game:
      return .none

    case .onAppear:
      return .merge(
        environment.audioPlayer.load(AudioPlayerClient.Sound.allCases)
          .fireAndForget(),

        Effect(value: .delayedOnAppear)
          .delay(
            for: 1,
            scheduler: environment.mainQueue.animation(.easeInOut(duration: fadeInDuration))
          )
          .eraseToEffect()
      )
    }
  }
  .binding()
)

public struct TrailerView: View {
  let store: Store<TrailerState, TrailerAction>
  @ObservedObject var viewStore: ViewStore<ViewState, TrailerAction>
  @Environment(\.deviceState) var deviceState

  struct ViewState: Equatable {
    let opacity: Double
    let selectedWordHasAlreadyBeenPlayed: Bool
    let selectedWordIsValid: Bool
    let selectedWordScore: Int?
    let selectedWordString: String

    init(state: TrailerState) {
      self.opacity = state.opacity
      self.selectedWordHasAlreadyBeenPlayed = state.game.selectedWordHasAlreadyBeenPlayed
      self.selectedWordIsValid = state.game.selectedWordIsValid
      self.selectedWordScore = self.selectedWordIsValid ? state.game.selectedWordScore : nil
      self.selectedWordString = state.game.selectedWordString
    }
  }

  public init(store: Store<TrailerState, TrailerAction>) {
    self.store = store
    self.viewStore = ViewStore(self.store.scope(state: ViewState.init(state:)))
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
                action: { .game(.wordSubmitButton($0)) }
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
            store: self.store.scope(
              state: \.game,
              action: TrailerAction.game
            )
          )
        }
        .adaptivePadding(.top, .grid(18))
        .adaptivePadding(.bottom, .grid(2))

        CubeView(
          store: self.store.scope(
            state: { CubeSceneView.ViewState(game: $0.game, nub: $0.nub, settings: .init()) },
            action: { .game(CubeSceneView.ViewAction.to(gameAction: $0)) }
          )
        )
        .adaptivePadding(
          self.deviceState.idiom == .pad ? .horizontal : [],
          .grid(30)
        )
      }
      .background(
        BloomBackground(
          size: proxy.size,
          store: self.store.actionless
            .scope(
              state: {
                BloomBackground.ViewState(
                  bloomCount: $0.game.selectedWord.count,
                  word: $0.game.selectedWordString
                )
              }
            )
        )
      )
    }
    .padding(
      self.deviceState.idiom == .pad ? .vertical : [],
      .grid(15)
    )
    .opacity(self.viewStore.opacity)
    .onAppear { self.viewStore.send(.onAppear) }
  }

  var scoreText: Text {
    self.viewStore.selectedWordScore.map {
      Text(" \($0)")
    } ?? Text("")
  }
}

private func moveNubDelay(
  wordIndex: Int,
  characterIndex: Int
) -> DispatchQueue.SchedulerTimeType.Stride {
  if wordIndex == 0 && characterIndex == 0 {
    return firstWordDelay
  } else if characterIndex == 0 {
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
