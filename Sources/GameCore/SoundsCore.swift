import AudioPlayerClient
import ComposableArchitecture
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
        guard
          let noteIndex = noteIndex(
            selectedWord: selectedWord,
            cubes: state.cubes,
            notes: AudioPlayerClient.Sound.allNotes
          )
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
          && previousSelection.contains { state.cubes[$0.index][$0.side].useCount == 2 }
        let cubeIsShaking =
          state.selectedWordIsValid
          && selectedWord.contains { state.cubes[$0.index][$0.side].useCount == 2 }

        let shakingEffect: Effect<GameAction, Never>
        if cubeIsShaking {
          state.cubeStartedShakingAt = state.cubeStartedShakingAt ?? environment.date()

          shakingEffect =
            cubeWasShaking
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
          shakingEffect = .cancel(id: CubeShakingId())
        }

        return .merge(
          environment.audioPlayer.play(AudioPlayerClient.Sound.allNotes[noteIndex])
            .fireAndForget(),
          shakingEffect
        )
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
      .onChange(of: \.selectedWord) { _, selectedWord, state, _, environment in
        let selectedWordString = state.cubes.string(from: selectedWord)
        guard
          !state.hasBeenPlayed(word: selectedWordString),
          environment.dictionary.contains(selectedWordString, state.language)
        else { return .none }

        let validCount = selectedWordString
          .indices
          .dropFirst(2)
          .reduce(0) { count, index in
            environment.dictionary.contains(String(selectedWordString[...index]), state.language)
              ? count + 1
              : count
          }

        return validCount > 0
          ? environment.audioPlayer.play(.validWord(level: validCount))
            .fireAndForget()
          : .none
      }
  }
}

private struct CubeShakingId: Hashable {}

private func noteIndex(
  selectedWord: [IndexedCubeFace],
  cubes: Puzzle,
  notes: [AudioPlayerClient.Sound]
) -> Int? {
  guard
    let firstFace = selectedWord.first,
    let firstAscii = cubes[firstFace.index][firstFace.side].letter.first?.utf8.first
  else { return nil }

  let firstIndex = Int(
    (firstAscii - .init(ascii: "A"))
      .quotientAndRemainder(dividingBy: .init(ascii: "O") - .init(ascii: "A"))
      .remainder
  )

  return min(
    firstIndex + selectedWord.count - 1,
    notes.count - 1
  )
}

extension GameState {
  func hasBeenPlayed(word: String) -> Bool {
    self.moves.contains {
      guard case let .playedWord(faces) = $0.type else { return false }
      return self.cubes.string(from: faces) == word
    }
  }
}
