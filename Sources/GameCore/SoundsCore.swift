import AudioPlayerClient
import ComposableArchitecture
import Dependencies
import SelectionSoundsCore
import SharedModels

extension Game {
  func sounds(state: inout State, action: Action) {
    switch action {
    case .confirmRemoveCube:
      store.addTask { await self.audioPlayer.play(.cubeRemove) }

    default:
      break
    }
  }

  func mountSounds(state: State) {
    let gameMode = state.gameMode
    let isDemo = state.isDemo
    store.addTask {
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
  }

  func gameOverChanged() {
    store.addTask {
      self.cubeShaking.cancel()
      for music in AudioPlayerClient.Sound.allMusic where music != .gameOverMusicLoop {
        await self.audioPlayer.stop(music)
      }
    }
  }

  func secondsPlayedChanged(_ secondsPlayed: Int, state: State) {
    if secondsPlayed == state.gameMode.seconds - 10 {
      store.addTask { await self.audioPlayer.play(.timed10SecWarning) }
    } else if secondsPlayed >= state.gameMode.seconds - 5
      && secondsPlayed <= state.gameMode.seconds
    {
      store.addTask { await self.audioPlayer.play(.timedCountdownTone) }
    }
  }

  func selectedWordChanged(
    from previousSelection: [IndexedCubeFace],
    to selectedWord: [IndexedCubeFace],
    state: inout State
  ) {
    if
      // Deselecting a word
      !previousSelection.isEmpty && selectedWord.isEmpty,
      // Previous selected word wasn't just played
      state.playedWords.last?.word != state.cubes.string(from: previousSelection)
    {
      let sound: AudioPlayerClient.Sound = self.isSubmittingWord ? .invalidWord : .cubeDeselect
      store.addTask { await self.audioPlayer.play(sound) }
    }

    guard !selectedWord.isEmpty
    else {
      state.cubeStartedShakingAt = nil
      store.addTask { self.cubeShaking.cancel() }
      return
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

      guard !cubeWasShaking else { return }
      store.addTask(id: self.cubeShaking) {
        await self.audioPlayer.play(.cubeShake)
        for await _ in self.clock.timer(interval: .seconds(2)) {
          await self.audioPlayer.play(.cubeShake)
        }
      }
    } else {
      state.cubeStartedShakingAt = nil
      store.addTask { self.cubeShaking.cancel() }
    }
  }

  func lastMoveChanged(_ lastMove: Move?, state: State) {
    guard
      let lastMove = lastMove,
      case let .playedWord(indexCubeFaces) = lastMove.type,
      let firstFace = indexCubeFaces.first,
      let firstAscii = state.cubes[firstFace.index][firstFace.side].letter.first?.utf8.first
    else { return }

    let firstIndex = Int(
      (firstAscii - .init(ascii: "A"))
        .quotientAndRemainder(dividingBy: .init(ascii: "O") - .init(ascii: "A"))
        .remainder
    )

    store.addTask {
      await self.audioPlayer.play(AudioPlayerClient.Sound.allSubmits[firstIndex])
    }
  }
}

extension Game.State {
  func hasBeenPlayed(word: String) -> Bool {
    self.moves.contains {
      $0.type.playedWord.map { self.cubes.string(from: $0) } == word
    }
  }
}
