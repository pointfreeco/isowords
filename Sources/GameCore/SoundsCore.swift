import AudioPlayerClient
import ComposableArchitecture
import SelectionSoundsCore

extension Reducer<Game.State, Game.Action> {
  func sounds() -> some Reducer<Game.State, Game.Action> {
    GameSounds(base: self)
  }
}

private struct GameSounds<Base: Reducer<Game.State, Game.Action>>: Reducer {
  @Dependency(\.audioPlayer) var audioPlayer
  @Dependency(\.date) var date
  @Dependency(\.dictionary.contains) var dictionaryContains
  @Dependency(\.mainQueue) var mainQueue

  let base: Base

  enum CancelID { case cubeShaking }

  var body: some Reducer<Game.State, Game.Action> {
    self.core
      .onChange(of: { $0.gameOver == nil }) { _, _ in
        Reduce { _, _ in
          .run { _ in
            Task.cancel(id: CancelID.cubeShaking)
            for music in AudioPlayerClient.Sound.allMusic where music != .gameOverMusicLoop {
              await self.audioPlayer.stop(music)
            }
          }
        }
      }
      .onChange(of: \.secondsPlayed) { _, secondsPlayed in
        Reduce { state, _ in
          if secondsPlayed == state.gameMode.seconds - 10 {
            return .run { _ in await self.audioPlayer.play(.timed10SecWarning) }
          } else if secondsPlayed >= state.gameMode.seconds - 5
            && secondsPlayed <= state.gameMode.seconds
          {
            return .run { _ in await self.audioPlayer.play(.timedCountdownTone) }
          } else {
            return .none
          }
        }
      }
      .onChange(of: \.selectedWord) { previousSelection, selectedWord in
        Reduce { state, action in
          guard
            // Deselecting a word
            !previousSelection.isEmpty && selectedWord.isEmpty,
            // Previous selected word wasn't just played
            state.playedWords.last?.word != state.cubes.string(from: previousSelection)
          else { return .none }

          switch action {
          case .submitButtonTapped, .wordSubmitButton(.delegate(.confirmSubmit)):
            return .run { _ in await self.audioPlayer.play(.invalidWord) }

          default:
            return .run { _ in await self.audioPlayer.play(.cubeDeselect) }
          }
        }
      }
      .onChange(of: \.selectedWord) { previousSelection, selectedWord in
        Reduce { state, _ in
          guard !selectedWord.isEmpty
          else {
            state.cubeStartedShakingAt = nil
            return .cancel(id: CancelID.cubeShaking)
          }

          let previousWord = state.cubes.string(from: previousSelection)
          let previousWordIsValid =
            self.dictionaryContains(previousWord, state.language)
            && !state.hasBeenPlayed(word: previousWord)
          let cubeWasShaking =
            previousWordIsValid
            && previousSelection.contains { state.cubes[$0].useCount == 2 }
          let cubeIsShaking =
            state.selectedWordIsValid
            && selectedWord.contains { state.cubes[$0].useCount == 2 }

          if cubeIsShaking {
            state.cubeStartedShakingAt = state.cubeStartedShakingAt ?? self.date()

            return cubeWasShaking
              ? .none
              : .run { _ in
                await self.audioPlayer.play(.cubeShake)
                for await _ in self.mainQueue.timer(interval: .seconds(2)) {
                  await self.audioPlayer.play(.cubeShake)
                }
              }
              .cancellable(id: CancelID.cubeShaking)

          } else {
            state.cubeStartedShakingAt = nil
            return .cancel(id: CancelID.cubeShaking)
          }
        }
      }
      .onChange(of: \.moves.last) { _, lastMove in
        Reduce { state, _ in
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

          return .run { _ in
            await self.audioPlayer.play(AudioPlayerClient.Sound.allSubmits[firstIndex])
          }
        }
      }
      .selectionSounds(
        contains: { self.dictionaryContains($1, $0.language) },
        hasBeenPlayed: { $0.hasBeenPlayed(word: $1) },
        puzzle: \.cubes,
        selectedWord: \.selectedWord
      )
  }

  @ReducerBuilder<Game.State, Game.Action>
  var core: some Reducer<Game.State, Game.Action> {
    self.base
    Reduce { state, action in
      switch action {
      case .task:
        return .run { [gameMode = state.gameMode, isDemo = state.isDemo] _ in
          if gameMode == .timed {
            await self.audioPlayer
              .play(
                isDemo
                  ? .timedGameBgLoop1
                  : [.timedGameBgLoop1, .timedGameBgLoop2].randomElement()!
              )

          } else {
            await self.audioPlayer
              .loop([.unlimitedGameBgLoop1, .unlimitedGameBgLoop2].randomElement()!)
          }
        }

      case .confirmRemoveCube:
        return .run { _ in await self.audioPlayer.play(.cubeRemove) }

      default:
        return .none
      }
    }
  }
}

extension Game.State {
  func hasBeenPlayed(word: String) -> Bool {
    self.moves.contains {
      guard case let .playedWord(faces) = $0.type else { return false }
      return self.cubes.string(from: faces) == word
    }
  }
}
