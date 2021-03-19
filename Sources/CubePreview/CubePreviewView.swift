import ComposableArchitecture
import CubeCore
import DictionaryClient
import GameCore
import SharedModels
import Styleguide
import SwiftUI

public struct CubePreviewState_: Equatable {
  var game: GameState
  var nub: CubeSceneView.ViewState.NubState
  var moveIndex: Int
}

public enum CubePreviewAction_: Equatable {
  case game(GameAction)
  case binding(BindingAction<CubePreviewState_>)
  case onAppear
}

import FeedbackGeneratorClient
public struct CubePreviewEnvironment {
  var dictionary: DictionaryClient
  var feedbackGenerator: FeedbackGeneratorClient

  public init(
    dictionary: DictionaryClient
  ) {
    self.dictionary = dictionary
  }
}

let cubePreviewReducer = Reducer<
CubePreviewState_,
CubePreviewAction_,
CubePreviewEnvironment
>.combine(

  gameReducer(
    state: \CubePreviewState_.game,
    action: /CubePreviewAction_.game,
    environment: {
      .init(
        apiClient: .noop,
        applicationClient: .noop,
        audioPlayer: .noop,
        backgroundQueue: DispatchQueue(label: "").eraseToAnyScheduler(),
        build: .noop,
        database: .noop,
        dictionary: $0.dictionary,
        feedbackGenerator: $0.feedbackGenerator,
        fileClient: .noop,
        gameCenter: .noop,
        lowPowerMode: .false,
        mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
        mainRunLoop: RunLoop.main.eraseToAnyScheduler(),
        remoteNotifications: .noop,
        serverConfig: .noop,
        setUserInterfaceStyle: { _ in .none },
        storeKit: .noop,
        userDefaults: .noop,
        userNotifications: .noop
      )
    },
    isHapticsEnabled: { _ in false }
  )

)


//public enum PreviewType: Equatable {
//  case game(Game)
//  case words(Words)
//
//  public struct Game: Equatable {
//    public var cubes: ArchivablePuzzle
//    public var currentMoveIndex: Index
//    public var moves: Moves
//
//    public enum Index: Equatable {
//      case end
//      case middle(Int)
//      case start
//    }
//
//    public init(
//      cubes: ArchivablePuzzle,
//      currentMoveIndex: Index = .start,
//      moves: Moves
//    ) {
//      self.cubes = cubes
//      self.currentMoveIndex = currentMoveIndex
//      self.moves = moves
//    }
//
//    var selectedWord: String? {
//      switch self.currentMoveIndex {
//      case .end:
//        return nil
//      case let .middle(index) where index < self.moves.count:
//        let move = self.moves[index]
//        switch move.type {
//        case let .playedWord(cubeFaces):
//          return self.cubes.string(from: cubeFaces)
//        case .removedCube:
//          return nil
//        }
//
//      case .middle:
//        return nil
//      case .start:
//        return nil
//      }
//    }
//
//    var selectedScore: Int? {
//      switch self.currentMoveIndex {
//      case .end:
//        return nil
//      case let .middle(index) where index < self.moves.count:
//        let move = self.moves[index]
//        switch move.type {
//        case .playedWord:
//          return move.score
//        case .removedCube:
//          return nil
//        }
//
//      case .middle:
//        return nil
//      case .start:
//        return nil
//      }
//    }
//  }
//
//  public struct Words: Equatable {
//    public var words: [Word]
//    public var currentWordIndex: Int
//
//    public init(
//      words: [Word],
//      currentWordIndex: Int = 0
//    ) {
//      self.words = words
//      self.currentWordIndex = currentWordIndex
//    }
//
//    var hasPreviousWords: Bool {
//      self.words.count > 1 && self.currentWordIndex > 0
//    }
//
//    var hasNextWords: Bool {
//      self.words.count > 1 && self.currentWordIndex != self.words.count - 1
//    }
//
//    var selectedWord: String? {
//      guard self.currentWordIndex < self.words.count else { return nil }
//      let word = self.words[self.currentWordIndex]
//      guard word.moveIndex < word.moves.count else { return nil }
//      let move = word.moves[word.moveIndex]
//
//      switch move.type {
//      case let .playedWord(cubeFaces):
//        return word.cubes.string(from: cubeFaces)
//      case .removedCube:
//        return nil
//      }
//    }
//
//    var selectedScore: Int? {
//      guard self.currentWordIndex < self.words.count else { return nil }
//      let word = self.words[self.currentWordIndex]
//      guard word.moveIndex < word.moves.count else { return nil }
//      let move = word.moves[word.moveIndex]
//
//      switch move.type {
//      case .playedWord:
//        return move.score
//      case .removedCube:
//        return nil
//      }
//    }
//  }
//
//  public struct Word: Equatable {
//    public var cubes: ArchivablePuzzle
//    public var moveIndex: Int
//    public var moves: Moves
//
//    public init(
//      cubes: ArchivablePuzzle,
//      moveIndex: Int,
//      moves: Moves
//    ) {
//      self.cubes = cubes
//      self.moveIndex = moveIndex
//      self.moves = moves
//    }
//  }
//}

//public struct CubePreviewState: Equatable {
//  public var preview: PreviewType
//
//  public init(
//    preview: PreviewType
//  ) {
//    self.preview = preview
//  }
//
//  var cubes: ArchivablePuzzle {
//    switch self.preview {
//    case let .game(game):
//      return game.cubes
//
//    case let .words(words):
//      return words.words[words.currentWordIndex].cubes
//    }
//  }
//
//  var moves: Moves {
//    switch self.preview {
//    case let .game(game):
//      return game.moves
//    case let .words(words):
//      return words.words[words.currentWordIndex].moves
//    }
//  }
//}

//public enum CubePreviewAction: Equatable {
//  case game(Game)
//  case onAppear
//  case word(Word)
//
//  public enum Game: Equatable {
//    case nextButtonTapped
//    case previousButtonTapped
//    case scene(CubeSceneView.ViewAction)
//  }
//
//  public enum Word: Equatable {
//    case nextButtonTapped
//    case previousButtonTapped
//    case scene(CubeSceneView.ViewAction)
//  }
//}

//public let cubePreviewReducer = Reducer<
//  CubePreviewState,
//  CubePreviewAction,
//  CubePreviewEnvironment
//>.combine(
//  gamePreviewReducer
//    ._pullback(
//      state: (\CubePreviewState.preview).appending(path: /PreviewType.game),
//      action: /CubePreviewAction.game,
//      environment: { _ in () }
//    ),
//
//  wordPreviewReducer
//    ._pullback(
//      state: (\CubePreviewState.preview).appending(path: /PreviewType.words),
//      action: /CubePreviewAction.word,
//      environment: { _ in () }
//    ),
//
//  .init { state, action, environment in
//    switch action {
//    case .game:
//      return .none
//
//    case .onAppear:
//      return .none
//
//    case .word:
//      return .none
//    }
//  }
//)

//let gamePreviewReducer = Reducer<PreviewType.Game, CubePreviewAction.Game, Void> {
//  state, action, environment in
//  switch action {
//  case .nextButtonTapped:
//    switch state.currentMoveIndex {
//    case .end:
//      return .none
//    case let .middle(index) where index < state.moves.count - 1:
//      state.currentMoveIndex = .middle(index + 1)
//      return .none
//    case .middle:
//      state.currentMoveIndex = .end
//      return .none
//    case .start:
//      state.currentMoveIndex = .middle(0)
//      return .none
//    }
//
//  case .previousButtonTapped:
//    switch state.currentMoveIndex {
//    case .end:
//      state.currentMoveIndex = .middle(state.moves.count - 1)
//      return .none
//    case let .middle(index) where index > 0:
//      state.currentMoveIndex = .middle(index - 1)
//      return .none
//    case .middle:
//      state.currentMoveIndex = .start
//      return .none
//    case .start:
//      return .none
//    }
//
//  case .scene:
//    return .none
//  }
//}

//let wordPreviewReducer = Reducer<PreviewType.Words, CubePreviewAction.Word, Void> {
//  state, action, environment in
//  switch action {
//  case .nextButtonTapped:
//    state.currentWordIndex += 1
//    return .none
//
//  case .previousButtonTapped:
//    state.currentWordIndex -= 1
//    return .none
//
//  case .scene:
//    return .none
//  }
//}

public struct CubePreviewView: View {
  let store: Store<CubePreviewState, CubePreviewAction>

  public init(store: Store<CubePreviewState, CubePreviewAction>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store) { viewStore in
      ZStack(alignment: Alignment(horizontal: .trailing, vertical: .top)) {
        switch viewStore.state.preview {
        case .game:
          IfLetStore(
            self.store.scope(
              state: (\CubePreviewState.preview).appending(path: /PreviewType.game).extract(from:),
              action: CubePreviewAction.game
            ),
            then: GamePreviewView.init(store:)
          )
        case .words:
          IfLetStore(
            self.store.scope(
              state: (\CubePreviewState.preview).appending(path: /PreviewType.words).extract(from:),
              action: CubePreviewAction.word
            ),
            then: WordPreviewView.init(store:)
          )
        }
      }
      .onAppear { viewStore.send(.onAppear) }
    }
  }
}

public struct GamePreviewView: View {
  let store: Store<PreviewType.Game, CubePreviewAction.Game>

  public var body: some View {
    WithViewStore(self.store) { viewStore in
      ZStack(alignment: .init(horizontal: .center, vertical: .top)) {
        IfLetStore(
          self.store.scope(
            state: CubeSceneView.ViewState.init(game:),
            action: CubePreviewAction.Game.scene
          ),
          then: CubeView.init(store:)
        )

        VStack {
          if let selectedWord = viewStore.selectedWord,
            let selectedScore = viewStore.selectedScore
          {
            HStack(alignment: .top) {
              Text(selectedWord.capitalized)
                .adaptiveFont(.matterSemiBold, size: 32)
                .lineLimit(1)
                .minimumScaleFactor(0.2)
              Text("\(selectedScore)")
                .adaptiveFont(.matterSemiBold, size: 24)
                .lineLimit(1)
                .minimumScaleFactor(0.2)
                .offset(y: -.grid(1))
            }
            .padding()
            .foregroundColor(.adaptiveBlack)
          }

          Spacer()

          VStack {
            HStack {
              if viewStore.currentMoveIndex != .start {
                Button(action: { viewStore.send(.previousButtonTapped) }) {
                  Image(systemName: "arrow.left")
                }
              }
              Spacer()
              if viewStore.currentMoveIndex != .end {
                Button(action: { viewStore.send(.nextButtonTapped) }) {
                  Image(systemName: "arrow.right")
                }
              }
            }
            .font(.largeTitle)
            .padding(32)
            .foregroundColor(.adaptiveBlack)
          }
        }
        .padding(.top, 32)
        .adaptivePadding([.leading, .trailing])
      }
    }
  }
}

public struct WordPreviewView: View {
  let store: Store<PreviewType.Words, CubePreviewAction.Word>

  public var body: some View {
    WithViewStore(self.store) { viewStore in
      ZStack {
        CubeView(
          store: self.store.scope(
            state: CubeSceneView.ViewState.init(words:),
            action: CubePreviewAction.Word.scene
          )
        )

        VStack {
          if let selectedWord = viewStore.selectedWord,
            let selectedScore = viewStore.selectedScore
          {
            (Text(selectedWord.capitalized).fontWeight(.medium)
              + Text("\(selectedScore)")
              .baselineOffset(10)
              .font(.custom(.matterMedium, size: 24)))
              .foregroundColor(.adaptiveBlack)
              .lineLimit(1)
              .minimumScaleFactor(0.2)
              .adaptiveFont(.matterMedium, size: 36)
              .padding()
          }

          Spacer()

          VStack {
            HStack {
              if viewStore.hasPreviousWords {
                Button(action: { viewStore.send(.previousButtonTapped) }) {
                  Image(systemName: "arrow.left")
                }
              }
              Spacer()
              if viewStore.hasNextWords {
                Button(action: { viewStore.send(.nextButtonTapped) }) {
                  Image(systemName: "arrow.right")
                }
              }
            }
            .font(.largeTitle)
            .padding(32)
            .foregroundColor(.white)
          }
        }
        .padding(.top, 32)
        .adaptivePadding([.leading, .trailing])
      }
    }
  }
}

extension CubeSceneView.ViewState {
  init(words: PreviewType.Words) {
    let word = words.words[words.currentWordIndex]
    var cubes = Puzzle(archivableCubes: word.cubes)
    apply(moves: word.moves[0..<word.moveIndex], to: &cubes)
    var viewStateCubes = select(
      move: word.moves[word.moveIndex], on: cubes, cubeShakeStartedAt: nil)
    LatticePoint.cubeIndices.forEach { index in
      viewStateCubes[index].isCriticallySelected = false
      viewStateCubes[index].left.cubeFace.useCount = 0
      viewStateCubes[index].right.cubeFace.useCount = 0
      viewStateCubes[index].top.cubeFace.useCount = 0
    }

    self.init(
      cubes: viewStateCubes,
      isOnLowPowerMode: false,
      nub: nil,
      playedWords: [],
      selectedFaceCount: 0,
      selectedWordIsValid: false,
      selectedWordString: "",
      settings: .init()
    )
  }
}

extension CubeSceneView.ViewState {
  init?(game: PreviewType.Game) {
    var cubes = Puzzle(archivableCubes: game.cubes)
    let viewStateCubes: CubeSceneView.ViewState.ViewPuzzle

    switch game.currentMoveIndex {
    case .end:
      return nil
    case let .middle(index):
      apply(moves: game.moves[0..<index], to: &cubes)
      viewStateCubes = select(move: game.moves[index], on: cubes, cubeShakeStartedAt: nil)
    case .start:
      viewStateCubes = .init(archivablePuzzle: game.cubes, cubeShakeStartedAt: nil)
    }

    self.init(
      cubes: viewStateCubes,
      isOnLowPowerMode: false,
      nub: nil,
      playedWords: [],
      selectedFaceCount: 0,
      selectedWordIsValid: false,
      selectedWordString: "",
      settings: .init()
    )
  }
}

extension CubeSceneView.ViewState.ViewPuzzle {
  init(
    archivablePuzzle: ArchivablePuzzle,
    cubeShakeStartedAt: Date?
  ) {
    self = archivablePuzzle.enumerated().map { x, cubes in
      cubes.enumerated().map { y, cubes in
        cubes.enumerated().map { z, cube in
          CubeNode.ViewState(
            cubeShakeStartedAt: cubeShakeStartedAt,
            index: .init(x: x, y: y, z: z),
            isCriticallySelected: false,
            isInPlay: true,
            left: .init(cubeFace: .init(archivableCubeFaceState: cube.left), status: .deselected),
            right: .init(cubeFace: .init(archivableCubeFaceState: cube.right), status: .deselected),
            top: .init(cubeFace: .init(archivableCubeFaceState: cube.top), status: .deselected))
        }
      }
    }
  }
}

func select(
  move: Move,
  on puzzle: Puzzle,
  cubeShakeStartedAt: Date?
) -> CubeSceneView.ViewState.ViewPuzzle {
  var viewStateCubes = puzzle.enumerated().map { x, cubes in
    cubes.enumerated().map { y, cubes in
      cubes.enumerated().map { z, cube in
        CubeNode.ViewState(
          cubeShakeStartedAt: cubeShakeStartedAt,
          index: .init(x: x, y: y, z: z),
          isCriticallySelected: false,
          isInPlay: cube.isInPlay,
          left: .init(
            cubeFace: .init(
              letter: cube.left.letter,
              side: cube.left.side,
              useCount: cube.left.useCount
            ),
            status: .deselected
          ),
          right: .init(
            cubeFace: .init(
              letter: cube.right.letter,
              side: cube.right.side,
              useCount: cube.right.useCount
            ),
            status: .deselected
          ),
          top: .init(
            cubeFace: .init(
              letter: cube.top.letter,
              side: cube.top.side,
              useCount: cube.top.useCount
            ),
            status: .deselected
          )
        )
      }
    }
  }
  switch move.type {
  case let .playedWord(cubeFaces):
    for cubeFace in cubeFaces {
      switch cubeFace.side {
      case .top:
        viewStateCubes[cubeFace.index].top.status = .selected
      case .left:
        viewStateCubes[cubeFace.index].left.status = .selected
      case .right:
        viewStateCubes[cubeFace.index].right.status = .selected
      }
    }
  case let .removedCube(index):
    viewStateCubes[index].isInPlay = false
  }

  return viewStateCubes
}
