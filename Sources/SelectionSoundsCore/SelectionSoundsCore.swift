import AudioPlayerClient
import ComposableArchitecture
import SharedModels
import TcaHelpers

extension Reducer {
  public func selectionSounds(
    audioPlayer: @escaping (Environment) -> AudioPlayerClient,
    contains: @escaping (State, Environment, String) -> Bool,
    hasBeenPlayed: @escaping (State, String) -> Bool,
    puzzle: @escaping (State) -> Puzzle,
    selectedWord: @escaping (State) -> [IndexedCubeFace]
  ) -> Reducer {
    self
      .onChange(of: selectedWord) { previousSelection, selectedWord, state, _, environment in
        var effects: [Effect<Action, Never>] = []

        if let noteIndex = noteIndex(
          selectedWord: selectedWord,
          cubes: puzzle(state),
          notes: AudioPlayerClient.Sound.allNotes
        ) {
          effects.append(
            audioPlayer(environment).play(AudioPlayerClient.Sound.allNotes[noteIndex])
              .fireAndForget()
          )
        }

        let selectedWordString = puzzle(state).string(from: selectedWord)
        if !hasBeenPlayed(state, selectedWordString)
          && contains(state, environment, selectedWordString)
        {

          let validCount = selectedWordString
            .indices
            .dropFirst(2)
            .reduce(into: 0) { count, index in
              count +=
                contains(state, environment, String(selectedWordString[...index]))
                ? 1
                : 0
            }
          effects.append(
            validCount > 0
              ? audioPlayer(environment).play(.validWord(level: validCount))
                .fireAndForget()
              : .none
          )
        }

        return .merge(effects)
      }
  }
}

private func noteIndex(
  selectedWord: [IndexedCubeFace],
  cubes: Puzzle,
  notes: [AudioPlayerClient.Sound]
) -> Int? {
  guard
    let firstFace = selectedWord.first,
    let firstAscii = cubes[firstFace].letter.first?.utf8.first
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
