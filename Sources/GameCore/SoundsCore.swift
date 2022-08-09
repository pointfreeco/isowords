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
          case .task:
            return .fireAndForget { [gameMode = state.gameMode, isDemo = state.isDemo] in
              if gameMode == .timed {
                await environment.audioPlayer
                  .play(
                    isDemo
                      ? .timedGameBgLoop1
                      : [.timedGameBgLoop1, .timedGameBgLoop2].randomElement()!
                  )

              } else {
                await environment.audioPlayer
                  .loop([.unlimitedGameBgLoop1, .unlimitedGameBgLoop2].randomElement()!)
              }
            }

          case .confirmRemoveCube:
            return .fireAndForget { await environment.audioPlayer.play(.cubeRemove) }

          default:
            return .none
          }
        }
      )
      .onChange(of: { $0.gameOver == nil }) { _, _, _, environment in
        .fireAndForget {
          await Task.cancel(id: CubeShakingID.self)
          for music in AudioPlayerClient.Sound.allMusic where music != .gameOverMusicLoop {
            await environment.audioPlayer.stop(music)
          }
        }
      }
      .onChange(of: \.secondsPlayed) { secondsPlayed, state, _, environment in
        if secondsPlayed == state.gameMode.seconds - 10 {
          return .fireAndForget { await environment.audioPlayer.play(.timed10SecWarning) }
        } else if secondsPlayed >= state.gameMode.seconds - 5
          && secondsPlayed <= state.gameMode.seconds
        {
          return .fireAndForget { await environment.audioPlayer.play(.timedCountdownTone) }
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
          return .fireAndForget { await environment.audioPlayer.play(.invalidWord) }

        default:
          return .fireAndForget { await environment.audioPlayer.play(.cubeDeselect) }
        }
      }
      .onChange(of: \.selectedWord) { previousSelection, selectedWord, state, _, environment in
        guard !selectedWord.isEmpty
        else {
          state.cubeStartedShakingAt = nil
          return .cancel(id: CubeShakingID.self)
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

          return cubeWasShaking ? .none : .fireAndForget {
            await environment.audioPlayer.play(.cubeShake)
            for await _ in environment.mainQueue.timer(interval: .seconds(2)) {
              await environment.audioPlayer.play(.cubeShake)
            }
          }
          .cancellable(id: CubeShakingID.self)

        } else {
          state.cubeStartedShakingAt = nil
          return .cancel(id: CubeShakingID.self)
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

        return .fireAndForget {
          await environment.audioPlayer.play(AudioPlayerClient.Sound.allSubmits[firstIndex])
        }
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

private enum CubeShakingID {}

extension GameState {
  func hasBeenPlayed(word: String) -> Bool {
    self.moves.contains {
      guard case let .playedWord(faces) = $0.type else { return false }
      return self.cubes.string(from: faces) == word
    }
  }
}
