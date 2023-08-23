import AudioPlayerClient
import ComposableArchitecture
import SharedModels
import TcaHelpers

extension Reducer {
  public func selectionSounds(
    contains: @escaping (State, String) -> Bool,
    hasBeenPlayed: @escaping (State, String) -> Bool,
    puzzle: @escaping (State) -> Puzzle,
    selectedWord: @escaping (State) -> [IndexedCubeFace]
  ) -> SelectionSounds<Self> {
    SelectionSounds(
      base: self,
      contains: contains,
      hasBeenPlayed: hasBeenPlayed,
      puzzle: puzzle,
      selectedWord: selectedWord
    )
  }
}

public struct SelectionSounds<Base: Reducer>: Reducer {
  let base: Base
  let contains: (Base.State, String) -> Bool
  let hasBeenPlayed: (Base.State, String) -> Bool
  let puzzle: (Base.State) -> Puzzle
  let selectedWord: (Base.State) -> [IndexedCubeFace]

  @Dependency(\.audioPlayer.play) var playSound

  public var body: some Reducer<Base.State, Base.Action> {
    self.base.onChange(of: self.selectedWord) { previousSelection, selection in
      Reduce { state, action in
        .run { [state] _ in
          if let noteIndex = noteIndex(
            selectedWord: selection,
            cubes: self.puzzle(state),
            notes: AudioPlayerClient.Sound.allNotes
          ) {
            await self.playSound(AudioPlayerClient.Sound.allNotes[noteIndex])
          }

          let selectedWordString = self.puzzle(state).string(from: selection)
          if !hasBeenPlayed(state, selectedWordString)
            && contains(state, selectedWordString)
          {
            let validCount = selectedWordString
              .indices
              .dropFirst(2)
              .reduce(into: 0) { count, index in
                count +=
                  contains(state, String(selectedWordString[...index]))
                  ? 1
                  : 0
              }
            if validCount > 0 {
              await self.playSound(.validWord(level: validCount))
            }
          }
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
