import AudioPlayerClient
import ComposableArchitecture
import SelectionSoundsCore
import SharedModels

extension Reducer where State == GameState, Action == GameAction, Environment == GameEnvironment {
  func sounds() -> Self {
    self
      .combined(
        with: .init { state, action, environment in
          switch action {
          case .onAppear:
            let soundEffect: Effect<Never, Never>
            if state.gameMode == .timed {
              soundEffect = environment.audioPlayer
                .play(
                  state.isDemo
                    ? .timedGameBgLoop1
                    : [.timedGameBgLoop1, .timedGameBgLoop2].randomElement()!
                )

            } else {
              soundEffect = environment.audioPlayer
                .loop([.unlimitedGameBgLoop1, .unlimitedGameBgLoop2].randomElement()!)
            }
            return
              soundEffect
              .fireAndForget()

          case .confirmRemoveCube:
            return environment.audioPlayer.play(.cubeRemove)
              .fireAndForget()

          default:
            return .none
          }
        }
      )
      .onChange(of: { $0.gameOver == nil }) { _, _, _, environment in
        .merge(
          Effect
            .merge(
              AudioPlayerClient.Sound.allMusic
                .filter { $0 != .gameOverMusicLoop }
                .map(environment.audioPlayer.stop)
            )
            .fireAndForget(),

          .cancel(id: CubeShakingId())
        )
      }
      .onChange(of: \.secondsPlayed) { secondsPlayed, state, _, environment in
        if secondsPlayed == state.gameMode.seconds - 10 {
          return environment.audioPlayer.play(.timed10SecWarning)
            .fireAndForget()
        } else if secondsPlayed >= state.gameMode.seconds - 5
          && secondsPlayed <= state.gameMode.seconds
        {
          return environment.audioPlayer.play(.timedCountdownTone)
            .fireAndForget()
        } else {
          return .none
        }
      }
      .onChange(of: \.selectedWord) { previousSelection, selectedWord, state, action, environment in
        guard
          // Deselecting a word
          !previousSelection.isEmpty && selectedWord.isEmpty,
          // Previous selected word wasn't just played
          state.playedWords.last?.word != state.cubes.string(from: previousSelection)
        else { return .none }

        switch action {
        case .submitButtonTapped, .wordSubmitButton(.delegate(.confirmSubmit)):
          return environment.audioPlayer.play(.invalidWord)
            .fireAndForget()

        default:
          return environment.audioPlayer.play(.cubeDeselect)
            .fireAndForget()
        }
      }
      .onChange(of: \.selectedWord) { previousSelection, selectedWord, state, _, environment in
        guard !selectedWord.isEmpty
        else {
          state.cubeStartedShakingAt = nil
          return .cancel(id: CubeShakingId())
        }

        let previousWord = state.cubes.string(from: previousSelection)
        let previousWordIsValid =
          environment.dictionary.contains(previousWord, state.language)
          && !state.hasBeenPlayed(word: previousWord)
        let cubeWasShaking =
          previousWordIsValid
          && previousSelection.contains { state.cubes[$0].useCount == 2 }
        let cubeIsShaking =
          state.selectedWordIsValid
          && selectedWord.contains { state.cubes[$0].useCount == 2 }

        if cubeIsShaking {
          state.cubeStartedShakingAt = state.cubeStartedShakingAt ?? environment.date()

          return cubeWasShaking
            ? .none
            : Effect.timer(
              id: CubeShakingId(),
              every: .seconds(2),
              on: environment.mainQueue
            )
            .flatMap { _ in environment.audioPlayer.play(.cubeShake) }
            .merge(with: environment.audioPlayer.play(.cubeShake))
            .eraseToEffect()
            .fireAndForget()

        } else {
          state.cubeStartedShakingAt = nil
          return .cancel(id: CubeShakingId())
        }
      }
      .onChange(of: \.moves.last) { lastMove, state, _, environment in
        guard
          let lastMove = lastMove,
          case let .playedWord(indexCubeFaces) = lastMove.type,
          let firstFace = indexCubeFaces.first,
          let firstAscii = state.cubes[firstFace.index][firstFace.side].letter.first?.utf8.first
        else { return .none }

        let firstIndex = Int(
          (firstAscii - .init(ascii: "A"))
            .quotientAndRemainder(dividingBy: .init(ascii: "O") - .init(ascii: "A"))
            .remainder
        )

        return environment.audioPlayer.play(AudioPlayerClient.Sound.allSubmits[firstIndex])
          .fireAndForget()
      }
      .selectionSounds(
        audioPlayer: \.audioPlayer,
        contains: { state, environment, string in
          environment.dictionary.contains(string, state.language)
        },
        hasBeenPlayed: { state, string in
          state.hasBeenPlayed(word: string)
        },
        puzzle: \.cubes,
        selectedWord: \.selectedWord
      )
  }
}

private struct CubeShakingId: Hashable {}

extension GameState {
  func hasBeenPlayed(word: String) -> Bool {
    self.moves.contains {
      guard case let .playedWord(faces) = $0.type else { return false }
      return self.cubes.string(from: faces) == word
    }
  }
}
