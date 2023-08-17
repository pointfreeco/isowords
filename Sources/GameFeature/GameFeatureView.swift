import ComposableArchitecture
import SettingsFeature
import SwiftUI

public struct GameFeatureView<Content>: View where Content: View {
  let content: Content
  let store: StoreOf<GameFeature>

  public init(
    content: Content,
    store: StoreOf<GameFeature>
  ) {
    self.content = content
    self.store = store
  }

  public var body: some View {
    IfLetStore(
      self.store.scope(state: \.game, action: { $0 }),
      then: { store in
        WithViewStore(
          self.store,
          observe: \.settings.userSettings.enableReducedAnimation
        ) { viewStore in
          GameView(
            content: self.content,
            isAnimationReduced: viewStore.state,
            store: store.scope(state: { $0 }, action: { .game($0) })
          )
        }
      }
    )
    .background(Color.adaptiveWhite)
    .background(
      WithViewStore(
        self.store,
        observe: { $0.game?.isSettingsPresented ?? false }
      ) {
        viewStore in
        // NB: If an .alert/.sheet modifier is used on a child view while the parent view is also
        // using an .alert/.sheet modifier, then the child view’s alert/sheet will never appear:
        // https://gist.github.com/mbrandonw/82ece7c62afb370a875fd1db2f9a236e
        EmptyView()
          .sheet(isPresented: viewStore.binding(send: .dismissSettings)) {
            NavigationView {
              SettingsView(
                store: self.store.scope(state: \.settings, action: { .settings($0) }),
                navPresentationStyle: .modal
              )
            }
          }
      }
    )
  }
}

#if DEBUG
  import FileClient
  import Overture
  import PuzzleGen
  import SharedModels

  struct GameFeatureView_Previews: PreviewProvider {
    static var previews: some View {
      Group {
        GameFeatureView(
          content: Text("Cube"),
          store: Store(
            initialState: GameFeature.State(
              game: Game.State(
                cubes: update(randomCubes(for: isowordsLetter).run()) {
                  $0.2.2.2 = Cube(
                    left: .init(letter: "C", side: .left),
                    right: .init(letter: "A", side: .right),
                    top: .init(letter: "B", side: .top)
                  )
                },
                gameContext: .solo,
                gameCurrentTime: Date(timeIntervalSinceReferenceDate: 120),
                gameMode: .unlimited,
                gameStartTime: Date(timeIntervalSinceReferenceDate: 0),
                isGameLoaded: true,
                moves: [
                  .init(
                    playedAt: .init(),
                    playerIndex: nil,
                    reactions: [0: .angel, 1: .anger],
                    score: 65,
                    type: .playedWord([
                      .init(index: .init(x: .two, y: .two, z: .two), side: .left),
                      .init(index: .init(x: .two, y: .two, z: .two), side: .right),
                      .init(index: .init(x: .two, y: .two, z: .two), side: .top),
                    ])
                  )
                ]  //,
                //              selectedWord: [
                //                .init(index: .init(x: .two, y: .two, z: .two), side: .left),
                //                .init(index: .init(x: .two, y: .two, z: .two), side: .right),
                //                .init(index: .init(x: .two, y: .two, z: .two), side: .top),
                //              ]
              ),
              settings: .init()
            )
          ) {
            GameFeature()
          }
        )
      }
      .ignoresSafeArea()
    }
  }
#endif
