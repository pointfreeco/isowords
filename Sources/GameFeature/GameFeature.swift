import AudioPlayerClient
import CasePaths
import ComposableArchitecture
import CubeCore
@_exported import GameCore
import SharedModels
import SettingsFeature

public struct GameFeatureState: Equatable {
  public var game: GameState?
  public var isReplaying: Bool
  public var nub: CubeSceneView.ViewState.NubState
  public var settings: SettingsState

  public init(
    game: GameState?,
    replay: ReplayState = .init(),
    settings: SettingsState
  ) {
    self.game = game
    self.isReplaying = replay.isReplaying
    self.nub = replay.nub
    self.settings = settings
  }

  public struct ReplayState: Equatable {
    public var isReplaying: Bool
    public var nub: CubeSceneView.ViewState.NubState

    public init(
      isReplaying: Bool = false,
      nub: CubeSceneView.ViewState.NubState = .init(location: .offScreenRight)
    ) {
      self.isReplaying = isReplaying
      self.nub = nub
    }
  }
}

public enum GameFeatureAction: Equatable {
  case game(GameAction)
  case nub(BindingAction<CubeSceneView.ViewState.NubState>)
  case onDisappear
  case replay(ReplayAction)
  case settings(SettingsAction)

  public enum ReplayAction: Equatable {
    case begin(moveIndex: Int)
    case deselectLastFace
    case enableSubmitButton
    case end(finalCubes: Puzzle)
    case lastTurnMoves
    case playMove(Move)
    case selectFace(IndexedCubeFace)
  }
}

public let gameFeatureReducer = Reducer<GameFeatureState, GameFeatureAction, GameEnvironment>
  .combine(
    settingsReducer
      .pullback(
        state: \GameFeatureState.settings,
        action: /GameFeatureAction.settings,
        environment: {
          SettingsEnvironment(
            apiClient: $0.apiClient,
            applicationClient: $0.applicationClient,
            audioPlayer: $0.audioPlayer,
            backgroundQueue: $0.backgroundQueue,
            build: $0.build,
            database: $0.database,
            feedbackGenerator: $0.feedbackGenerator,
            fileClient: $0.fileClient,
            lowPowerMode: $0.lowPowerMode,
            mainQueue: $0.mainQueue,
            remoteNotifications: $0.remoteNotifications,
            serverConfig: $0.serverConfig,
            setUserInterfaceStyle: $0.setUserInterfaceStyle,
            storeKit: $0.storeKit,
            userDefaults: $0.userDefaults,
            userNotifications: $0.userNotifications
          )
        }
      ),

    gameReducer(
      state: OptionalPath(\.game),
      action: /GameFeatureAction.game,
      environment: { $0 },
      isHapticsEnabled: \.settings.userSettings.enableHaptics
    ),

    Reducer { state, action, environment in

      struct ReplayId: Hashable {}

      switch action {
      case .game(.gameCenter(.listener(.turnBased(.receivedTurnEventForMatch)))):
        print(1)
        guard
          let game = state.game,
          let turnBasedContext = game.turnBasedContext
        else { return .none }

        return Effect(value: .replay(.lastTurnMoves))

      case .game:
        return .none

      case .nub:
        return .none

      case .onDisappear:
        return Effect.gameTearDownEffects(audioPlayer: environment.audioPlayer)
          .fireAndForget()

      case let .replay(.begin(startIndex)):
        print(2)
        guard
          let game = state.game,
          startIndex <= game.moves.endIndex
        else { return .none }

        let replayMoves = game.moves[startIndex...]
        guard !replayMoves.isEmpty else { return .none }

        state.isReplaying = true
        state.nub.location = .offScreenRight

        let finalCubes = game.cubes
        let previousMoves = Moves(game.moves[..<startIndex])
        state.game?.moves = previousMoves
        state.game?.cubes = Puzzle(
          archivableCubes: .init(cubes: finalCubes),
          moves: previousMoves
        )

        let tap: Effect<GameFeatureAction, Never> = .concatenate(
          // Press the nub
          Effect(value: .nub(.set(\.isPressed, true)))
            .receive(on: environment.mainQueue.animate(withDuration: submitPressDuration))
            .eraseToEffect(),

          // Release the nub
          Effect(value: .nub(.set(\.isPressed, false)))
            .delay(
              for: .seconds(submitPressDuration),
              scheduler: environment.mainQueue.animate(withDuration: 0.3)
            )
            .eraseToEffect()
        )

        var effects: [Effect<GameFeatureAction, Never>] = [
          Effect.none
            .delay(for: game.isGameLoaded ? 1 : firstWordDelay, scheduler: environment.mainQueue)
            .eraseToEffect()
        ]

        for (index, move) in zip(replayMoves.indices, replayMoves) {
          switch move.type {
          case let .playedWord(word):
            // Wait a small about of time before each word
            effects.append(
              Effect.none
                .delay(for: firstCharacterDelay, scheduler: environment.mainQueue)
                .eraseToEffect()
            )

            // Play each character in the word
            for (characterIndex, character) in word.enumerated() {
              let face = IndexedCubeFace(index: character.index, side: character.side)

              // Move the nub to the face being played
              effects.append(
                Effect(value: .nub(.set(\.location, .face(face))))
                  .receive(
                    on: environment.mainQueue
                      .animate(withDuration: moveNubToFaceDuration, options: .curveEaseInOut)
                  )
                  .eraseToEffect()
              )
              effects.append(
                Effect.merge(
                  // Press the nub on the first character
                  characterIndex == 0 ? Effect(value: .nub(.set(\.isPressed, true))) : .none,
                  // Tap on each face in the word being played
                  Effect(value: .replay(.selectFace(face)))
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
            effects.append(Effect(value: .replay(.enableSubmitButton)))

            // Release the nub when the last character is played
            effects.append(
              Effect(value: .nub(.set(\.isPressed, false)))
                .receive(on: environment.mainQueue.animate(withDuration: 0.3))
                .eraseToEffect()
            )
            // Move the nub to the submit button
            effects.append(
              Effect(value: .nub(.set(\.location, .submitButton)))
                .delay(
                  for: 0.2,
                  scheduler: environment.mainQueue
                    .animate(withDuration: moveNubToSubmitButtonDuration, options: .curveEaseInOut)
                )
                .eraseToEffect()
            )
            // Submit the word after waiting a small amount of time
            effects.append(
              Effect(value: .replay(.playMove(move)))
                .delay(
                  for: .seconds(
                    .random(
                      in:
                        moveNubToSubmitButtonDuration...(moveNubToSubmitButtonDuration
                                                          + submitHesitationDuration)
                    )
                  ),
                  scheduler: environment.mainQueue.animation()
                )
                .eraseToEffect()
            )
            effects.append(tap)

          case let .removedCube(latticePoint):
            let side = CubeFace.Side(rawValue: index % CubeFace.Side.allCases.count)!

            effects.append(contentsOf: [
              // Move the nub to the cube
              Effect(value: .nub(.set(\.location, .latticePoint(latticePoint))))
                .delay(
                  for: 0.2,
                  scheduler: environment.mainQueue
                    .animate(withDuration: moveNubToSubmitButtonDuration, options: .curveEaseInOut)
                )
                .eraseToEffect(),

              // Double-tap
              tap
                .delay(for: 0.65, scheduler: environment.mainQueue)
                .eraseToEffect(),

              Effect(value: .replay(.selectFace(IndexedCubeFace(index: latticePoint, side: side)))),

              tap
                .delay(for: 0.2, scheduler: environment.mainQueue)
                .eraseToEffect(),

              Effect(value: .replay(.deselectLastFace)),
            ])

            // Remove the cube
            effects.append(
              Effect(value: .replay(.playMove(move)))
                .delay(for: 0.2, scheduler: environment.mainQueue)
                .eraseToEffect()
            )
          }
        }

        // Move the nub off screen once all words have been played
        effects.append(
          Effect(value: .nub(.set(\.location, .offScreenBottom)))
            .delay(for: .seconds(0.3), scheduler: environment.mainQueue)
            .receive(
              on: environment.mainQueue
                .animate(withDuration: moveNubOffScreenDuration, options: .curveEaseInOut)
            )
            .eraseToEffect()
        )

        return .concatenate(
          Effect.concatenate(effects)
            .cancellable(id: ReplayId()),

          .init(value: .replay(.end(finalCubes: finalCubes)))
        )

      case .replay(.deselectLastFace):
        guard state.game?.selectedWord.isEmpty == false else { return .none }
        state.game?.selectedWord.removeLast()
        return environment.feedbackGenerator.selectionChanged()
          .fireAndForget()

      case .replay(.enableSubmitButton):
        state.game?.selectedWordIsValid = true
        return .none

      case let .replay(.end(cubes)):
        state.game?.cubes = cubes
        state.isReplaying = false
        return .none

      case .replay(.lastTurnMoves):
        print(3)
        guard
          let game = state.game,
          !game.isGameOver,
          let turnBasedContext = game.turnBasedContext,
//          let lastOpenedAt = turnBasedContext.metadata.lastOpenedAt,
//          lastOpenedAt < turnBasedContext.lastPlayedAt,
          let localPlayerIndex = turnBasedContext.localPlayerIndex,
          let replayStartIndex = game.moves.index(
            game.moves
              .lastIndex(where: { $0.playerIndex == turnBasedContext.localPlayerIndex }) ?? -1,
            offsetBy: 1, limitedBy: game.moves.endIndex
          )
        else { return .none }

        guard turnBasedContext.currentParticipantIsLocalPlayer
        else {
          let previousMoves = Moves(game.moves[..<replayStartIndex])
          state.game?.moves = previousMoves
          state.game?.cubes = Puzzle(
            archivableCubes: .init(cubes: game.cubes),
            moves: previousMoves
          )
          return .none
        }

        return Effect(value: .replay(.begin(moveIndex: replayStartIndex)))

      case let .replay(.playMove(move)):
        state.game?.moves.append(move)
        if var cubes = state.game?.cubes {
          apply(move: move, to: &cubes)
          state.game?.cubes = cubes
        }
        state.game?.selectedWord = []
        state.game?.selectedWordIsValid = false
        return environment.feedbackGenerator.selectionChanged()
          .fireAndForget()

      case let .replay(.selectFace(index)):
        state.game?.selectedWord.append(index)
        return environment.feedbackGenerator.selectionChanged()
          .fireAndForget()

      case .settings(.onDismiss):
        state.game?.isSettingsPresented = false
        return .none

      case .settings:
        return .none
      }
    }
    .binding(state: \.nub, action: /GameFeatureAction.nub)
  )

private let firstCharacterDelay: DispatchQueue.SchedulerTimeType.Stride = 0.3
private let firstWordDelay: DispatchQueue.SchedulerTimeType.Stride = 2.5
private let moveNubToFaceDuration = 0.45
private let moveNubToSubmitButtonDuration = 0.4
private let moveNubOffScreenDuration = 0.5
private let fadeInDuration = 0.3
private let fadeOutDuration = 0.3
private let submitPressDuration = 0.05
private let submitHesitationDuration = 0.15
