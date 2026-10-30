import AudioPlayerClient
import Bloom
import ComposableArchitecture
import CubeCore
import Dependencies
import GameCore
import SharedModels
import SwiftUI
import Styleguide
import TcaHelpers
import UIApplicationClient

@Feature
public struct Trailer {
  public struct State {
    @DebugSnapshotTracked var game: Game.State
    @DebugSnapshotTracked var nub: CubeSceneView.ViewState.NubState
    @DebugSnapshotTracked var opacity: Double

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
      self.init(
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
      .init(game: game, nub: nub)
    }
  }

  public enum Action {
    case game(Game.Action)
  }

  @Dependency(\.audioPlayer) var audioPlayer
  @FeatureEnvironment(\.continuousClock) var clock

  public init() {}

  public var body: some Feature {
    Scope(\.game) {
      Game(startsOnMount: false)
    }
    .transformDependency(\.self) {
      $0.apiClient = .noop
      $0.applicationClient = .noop
      $0.audioPlayer = audioPlayer
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
    .onMount { state in
      let nub = state.nub
      store.addTask {
        var nub = nub
        await audioPlayer.load(AudioPlayerClient.Sound.allCases)

        // Play trailer music
        await audioPlayer.play(.onboardingBgMusic)

        // Fade the cube in after a second
        try withAnimation(.easeInOut(duration: fadeInDuration)) {
          _ = try store.modify { $0.opacity = 1 }
        }
        try await clock.sleep(for: firstWordDelay)

        // Play each word
        for word in replayableWords {
          // Play each character in the word
          for (characterIndex, character) in word.enumerated() {
            let face = IndexedCubeFace(index: character.index, side: character.side)

            // Move the nub to the face being played
            nub.location = .face(face)
            await store.modify(
              animateWithDuration: moveNubToFaceDuration,
              options: .curveEaseInOut
            ) { [nub] in
              $0.nub = nub
            }
            try await clock.sleep(
              for: moveNubDelay(characterIndex: characterIndex)
            )

            try await clock.sleep(
              for: .seconds(
                .random(in: (0.3 * moveNubToFaceDuration)...(0.7 * moveNubToFaceDuration)))
            )
            // Press the nub on the first character
            nub.isPressed = true
            if characterIndex == 0 {
              await store.modify(animateWithDuration: 0.3) { [nub] in $0.nub = nub }
            }
            // Select the cube face
            try withAnimation {
              _ = try store.send(.game(.tap(.began, face)))
            }
          }

          // Release the  nub when the last character is played
          nub.isPressed = false
          await store.modify(animateWithDuration: 0.3) { [nub] in $0.nub = nub }

          // Move the nub to the submit button
          try await clock.sleep(for: .seconds(0.3))

          nub.location = .submitButton
          await store.modify(
            animateWithDuration: moveNubToSubmitButtonDuration,
            options: .curveEaseInOut
          ) { [nub] in
            $0.nub = nub
          }

          // Press the nub
          try await clock.sleep(
            for: .seconds(
              .random(
                in:
                  moveNubToSubmitButtonDuration...(moveNubToSubmitButtonDuration
                  + submitHestitationDuration)
              )
            )
          )

          // Submit the word
          try await clock.sleep(for: .seconds(0.1))
          await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { [nub] in
              var nub = nub
              nub.isPressed = true
              await store.modify(animateWithDuration: 0.3) { [nub] in $0.nub = nub }
            }
            group.addTask { [nub] in
              var nub = nub
              try await clock.sleep(for: .seconds(0.2))
              try await MainActor.run {
                _ = try store.send(.game(.submitButtonTapped(reaction: nil)))
              }
              try await clock.sleep(for: .seconds(0.3))
              nub.isPressed = false
              await store.modify(animateWithDuration: 0.3) { [nub] in $0.nub = nub }
            }
          }
        }

        // Move the nub off screen once all words have been played
        try await clock.sleep(for: .seconds(0.3))
        nub.location = .offScreenBottom
        await store.modify(
          animateWithDuration: moveNubOffScreenDuration,
          options: .curveEaseInOut
        ) { [nub] in
          $0.nub = nub
        }

        try withAnimation(.linear(duration: moveNubOffScreenDuration)) {
          _ = try store.modify { $0.opacity = 0 }
        }
      }
    }
  }
}

public struct TrailerView: View {
  let store: StoreOf<Trailer>
  @Environment(\.deviceState) var deviceState

  public init(store: StoreOf<Trailer>) {
    self.store = store
  }

  public var body: some View {
    GeometryReader { proxy in
      ZStack {
        VStack {
          if !store.game.selectedWordString.isEmpty {
            (Text(store.game.selectedWordString)
              + scoreText
              .baselineOffset(
                (deviceState.idiom == .pad ? 2 : 1) * 16
              )
              .font(
                .custom(
                  .matterMedium,
                  size: (deviceState.idiom == .pad ? 2 : 1) * 20
                )
              ))
              .adaptiveFont(
                .matterSemiBold,
                size: (deviceState.idiom == .pad ? 2 : 1) * 32
              )
              .opacity(store.game.selectedWordIsValid ? 1 : 0.5)
              .allowsTightening(true)
              .minimumScaleFactor(0.2)
              .lineLimit(1)
              .transition(.opacity)
              .animation(nil, value: store.game.selectedWordString)
          }

          Spacer()

          if !store.game.selectedWordString.isEmpty {
            WordSubmitButton(store: store.scope(\.game).scope(\.wordSubmitButtonFeature))
            .transition(
              AnyTransition
                .asymmetric(insertion: .offset(y: 50), removal: .offset(y: 50))
                .combined(with: .opacity)
            )
            .offset(y: .grid(6))
          }

          WordListView(
            isLeftToRight: true,
            store: store.scope(\.game)
          )
        }
        .adaptivePadding(.top, .grid(18))
        .adaptivePadding(.bottom, .grid(2))

        CubeView(
          store: store,
          state: \.cubeScene,
          action: { .game(CubeSceneView.ViewAction.to(gameAction: $0)) }
        )
          .adaptivePadding(
            deviceState.idiom == .pad ? .horizontal : [],
            .grid(30)
          )
      }
      .background {
        BloomBackground(
          size: proxy.size,
          word: store.game.selectedWordString
        )
      }
    }
    .padding(
      deviceState.idiom == .pad ? .vertical : [],
      .grid(15)
    )
    .opacity(store.opacity)
  }

  var scoreText: Text {
    if store.game.selectedWordIsValid {
      return Text(" \(store.game.selectedWordScore)")
    } else {
      return Text(verbatim: "")
    }
  }
}

private func moveNubDelay(characterIndex: Int) -> Duration {
  if characterIndex == 0 {
    return firstCharacterDelay
  } else {
    return .zero
  }
}

private let firstCharacterDelay: Duration = .seconds(0.3)
private let firstWordDelay: Duration = .seconds(1.5)
private let moveNubToFaceDuration = 0.45
private let moveNubToSubmitButtonDuration = 0.4
private let moveNubOffScreenDuration = 0.5
private let fadeInDuration = 0.3
private let fadeOutDuration = 0.3
private let submitPressDuration = 0.05
private let submitHestitationDuration = 0.15
