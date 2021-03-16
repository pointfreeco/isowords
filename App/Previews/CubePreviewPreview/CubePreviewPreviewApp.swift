import CubeCore
import PuzzleGen
import SharedModels
import SwiftUI

@testable import CubePreview

@main
struct CubePreviewPreviewApp: App {
  @State var wordPreviewIsPresented = false
  @State var gamePreviewIsPresented = false

  var body: some Scene {
    WindowGroup {
      NavigationView {
        Form {
          Button("Word Preview") { self.wordPreviewIsPresented = true }
            .sheet(isPresented: self.$wordPreviewIsPresented) {
              CubePreviewView(
                store: .init(
                  initialState: .init(
                    preview: .words(
                      .init(
                        words: [word]
                      )
                    )
                  ),
                  reducer: cubePreviewReducer,
                  environment: CubePreviewEnvironment()
                )
              )
            }

          Button("Game Preview") { self.gamePreviewIsPresented = true }
            .sheet(isPresented: self.$gamePreviewIsPresented) {
              CubePreviewView(
                store: .init(
                  initialState: .init(
                    preview: .game(
                      .init(
                        cubes: .init(cubes: randomCubes(for: isowordsLetter).run()),
                        moves: word.moves
                      )
                    )
                  ),
                  reducer: cubePreviewReducer,
                  environment: CubePreviewEnvironment()
                )
              )
            }
        }
        .navigationTitle(Text("Cube Preview"))
      }
    }
  }
}

let word = PreviewType.Word(
  cubes: .init(cubes: randomCubes(for: isowordsLetter).run()),
  moveIndex: 5,
  moves: [
    .init(
      playedAt: Date(),
      playerIndex: nil,
      reactions: nil,
      score: 0,
      type: .removedCube(.init(x: .two, y: .two, z: .two))
    ),
    .init(
      playedAt: Date(),
      playerIndex: nil,
      reactions: nil,
      score: 0,
      type: .removedCube(.init(x: .two, y: .one, z: .two))
    ),
    .init(
      playedAt: Date(),
      playerIndex: nil,
      reactions: nil,
      score: 0,
      type: .removedCube(.init(x: .one, y: .two, z: .two))
    ),
    .init(
      playedAt: Date(),
      playerIndex: nil,
      reactions: nil,
      score: 0,
      type: .removedCube(.init(x: .two, y: .two, z: .one))
    ),
    .init(
      playedAt: Date(),
      playerIndex: nil,
      reactions: nil,
      score: 100,
      type: .playedWord([
        .init(index: .init(x: .one, y: .zero, z: .two), side: .left),
        .init(index: .init(x: .zero, y: .zero, z: .two), side: .left),
        .init(index: .init(x: .one, y: .one, z: .two), side: .left),
        .init(index: .init(x: .one, y: .two, z: .two), side: .left),
        .init(index: .init(x: .zero, y: .two, z: .two), side: .left),
      ])
    ),
    .init(
      playedAt: Date(),
      playerIndex: nil,
      reactions: nil,
      score: 100,
      type: .playedWord([
        .init(index: .init(x: .two, y: .zero, z: .two), side: .left),
        .init(index: .init(x: .two, y: .zero, z: .two), side: .top),
        .init(index: .init(x: .two, y: .one, z: .one), side: .left),
        .init(index: .init(x: .one, y: .two, z: .one), side: .left),
        .init(index: .init(x: .zero, y: .two, z: .one), side: .top),
      ])
    ),
  ]
)
