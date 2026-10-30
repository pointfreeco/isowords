import AudioPlayerClient
import ComposableArchitecture
import Dependencies
import SharedModels

extension FeatureProtocol {
  public func selectionSounds(
    contains: @escaping (State, String) -> Bool,
    hasBeenPlayed: @escaping (State, String) -> Bool,
    puzzle: @escaping (State) -> Puzzle,
    selectedWord: [IndexedCubeFace]
  ) -> some Feature {
    self.modifier(
      SelectionSounds(
        contains: contains,
        hasBeenPlayed: hasBeenPlayed,
        puzzle: puzzle,
        selectedWord: selectedWord
      )
    )
  }
}

@FeatureModifier
private struct SelectionSounds<State, Action> {
  let contains: (State, String) -> Bool
  let hasBeenPlayed: (State, String) -> Bool
  let puzzle: (State) -> Puzzle
  let selectedWord: [IndexedCubeFace]

  @Dependency(\.audioPlayer.play) var playSound

  func body(content: Content) -> some Feature {
    content.onChange(of: selectedWord) { _, selection, state in
      let puzzle = self.puzzle(state)
      let selectedWordString = puzzle.string(from: selection)
      let validCount =
        !hasBeenPlayed(state, selectedWordString) && contains(state, selectedWordString)
        ? selectedWordString
          .indices
          .dropFirst(2)
          .reduce(into: 0) { count, index in
            count += contains(state, String(selectedWordString[...index])) ? 1 : 0
          }
        : 0
      store.addTask {
        if let noteIndex = noteIndex(
          selectedWord: selection,
          cubes: puzzle,
          notes: AudioPlayerClient.Sound.allNotes
        ) {
          await playSound(AudioPlayerClient.Sound.allNotes[noteIndex])
        }
        if validCount > 0 {
          await playSound(.validWord(level: validCount))
        }
      }
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
