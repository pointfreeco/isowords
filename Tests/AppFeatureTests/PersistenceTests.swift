import BottomMenu
import ClientModels
import Combine
import ComposableArchitecture
import ComposableUserNotifications
import FeedbackGeneratorClient
import GameFeature
import GameOverFeature
import HomeFeature
import Overture
import ServerRouter
import SettingsFeature
import SharedModels
import SwiftUI
import TestHelpers
import XCTest

@testable import AppFeature
@testable import FileClient
@testable import GameCore
@testable import SoloFeature
@testable import UserDefaultsClient

@MainActor
class PersistenceTests: XCTestCase {
  func testUnlimitedSaveAndQuit() async throws {
    let saves = ActorIsolated<[Data]>([])

    let store = TestStore(
      initialState: .init(
        home: .init(route: .solo(.init()))
      ),
      reducer: appReducer,
      environment: update(.unimplemented) {
        $0.audioPlayer.play = { _ in }
        $0.audioPlayer.stop = { _ in }
        $0.backgroundQueue = .immediate
        $0.dictionary.contains = { word, _ in word == "CAB" }
        $0.dictionary.randomCubes = { _ in .mock }
        $0.feedbackGenerator = .noop
        $0.fileClient.save = { @Sendable _, data in await saves.withValue { $0.append(data) } }
        $0.mainRunLoop = .immediate
        $0.mainQueue = .immediate
      }
    )

    let index = LatticePoint(x: .two, y: .two, z: .two)
    let C = IndexedCubeFace(index: index, side: .top)
    let A = IndexedCubeFace(index: index, side: .left)
    let B = IndexedCubeFace(index: index, side: .right)

    await store.send(.home(.solo(.gameButtonTapped(.unlimited)))) {
      $0.game = GameState(
        cubes: .mock,
        gameContext: .solo,
        gameCurrentTime: RunLoop.immediate.now.date,
        gameMode: .unlimited,
        gameStartTime: RunLoop.immediate.now.date
      )
      $0.home.savedGames.unlimited = $0.game.map(InProgressGame.init)
    }
    await store.send(.currentGame(.game(.tap(.began, C)))) {
      try XCTUnwrap(&$0.game) {
        $0.optimisticallySelectedFace = C
        $0.selectedWord = [C]
      }
    }
    await store.send(.currentGame(.game(.tap(.ended, C)))) {
      try XCTUnwrap(&$0.game) {
        $0.optimisticallySelectedFace = nil
      }
    }
    await store.send(.currentGame(.game(.tap(.began, A)))) {
      try XCTUnwrap(&$0.game) {
        $0.optimisticallySelectedFace = A
        $0.selectedWord = [C, A]
      }
    }
    await store.send(.currentGame(.game(.tap(.ended, A)))) {
      try XCTUnwrap(&$0.game) {
        $0.optimisticallySelectedFace = nil
      }
    }
    await store.send(.currentGame(.game(.tap(.began, B)))) {
      try XCTUnwrap(&$0.game) {
        $0.optimisticallySelectedFace = B
        $0.selectedWord = [C, A, B]
        $0.selectedWordIsValid = true
      }
    }
    await store.send(.currentGame(.game(.tap(.ended, B)))) {
      try XCTUnwrap(&$0.game) {
        $0.optimisticallySelectedFace = nil
      }
    }
    await store.send(.currentGame(.game(.submitButtonTapped(reaction: nil)))) {
      try XCTUnwrap(&$0.game) {
        $0.moves = [
          .init(
            playedAt: RunLoop.immediate.now.date,
            playerIndex: nil,
            reactions: nil,
            score: 27,
            type: .playedWord($0.selectedWord)
          )
        ]
        $0.selectedWord = []
        $0.selectedWordIsValid = false
        $0.cubes[index].left.useCount = 1
        $0.cubes[index].right.useCount = 1
        $0.cubes[index].top.useCount = 1
      }
      $0.home.savedGames.unlimited = $0.game.map(InProgressGame.init)
    }
    await store.send(.currentGame(.game(.menuButtonTapped))) {
      try XCTUnwrap(&$0.game) {
        $0.bottomMenu = .init(
          title: .init("Solo"),
          message: nil,
          buttons: [
            .init(
              title: .init("Main menu"),
              icon: .exit,
              action: .init(action: .exitButtonTapped, animation: .default)
            ),
            .init(
              title: .init("End game"),
              icon: .flag,
              action: .init(action: .endGameButtonTapped, animation: .default)
            ),
          ],
          footerButton: .init(
            title: .init("Settings"),
            icon: .init(systemName: "gear"),
            action: .init(action: .settingsButtonTapped, animation: .default)
          ),
          onDismiss: .init(action: .dismissBottomMenu, animation: .default)
        )
      }
    }
    await store.send(.currentGame(.game(.exitButtonTapped))) { appState in
      try XCTUnwrap(&appState.game) { game in
        appState.home.savedGames.unlimited = InProgressGame(gameState: game)
      }
      appState.game = nil
    }
    try await saves.withValue {
      XCTAssertNoDifference(2, $0.count)
      XCTAssertNoDifference($0.last, try JSONEncoder().encode(store.state.home.savedGames))
    }
  }

  func testUnlimitedAbandon() async throws {
    let didArchiveGame = ActorIsolated(false)
    let saves = ActorIsolated<[Data]>([])

    let store = TestStore(
      initialState: AppState(
        game: update(.mock) { $0.gameMode = .unlimited },
        home: HomeState(savedGames: SavedGamesState(unlimited: .mock))
      ),
      reducer: appReducer,
      environment: update(.unimplemented) {
        $0.audioPlayer.stop = { _ in }
        $0.backgroundQueue = .immediate
        $0.database.saveGame = { _ in await didArchiveGame.setValue(true) }
        $0.gameCenter.localPlayer.localPlayer = { .notAuthenticated }
        $0.fileClient.save = { @Sendable _, data in await saves.withValue { $0.append(data) } }
        $0.mainQueue = .immediate
      }
    )

    await store.send(.currentGame(.game(.menuButtonTapped))) {
      try XCTUnwrap(&$0.game) {
        $0.bottomMenu = .init(
          title: .init("Solo"),
          message: nil,
          buttons: [
            .init(
              title: .init("Main menu"),
              icon: .exit,
              action: .init(action: .exitButtonTapped, animation: .default)
            ),
            .init(
              title: .init("End game"),
              icon: .flag,
              action: .init(action: .endGameButtonTapped, animation: .default)
            ),
          ],
          footerButton: .init(
            title: .init("Settings"),
            icon: .init(systemName: "gear"),
            action: .init(action: .settingsButtonTapped, animation: .default)
          ),
          onDismiss: .init(action: .dismissBottomMenu, animation: .default)
        )
      }
    }
    await store.send(.currentGame(.game(.endGameButtonTapped))) {
      try XCTUnwrap(&$0.game) {
        $0.gameOver = GameOverState(
          completedGame: .init(gameState: $0),
          isDemo: false
        )
        $0.bottomMenu = nil
      }
      $0.home.savedGames.unlimited = nil
    }

    await didArchiveGame.withValue { XCTAssert($0) }
    try await saves.withValue {
      XCTAssertNoDifference($0, [try JSONEncoder().encode(SavedGamesState())])
    }
  }

  func testTimedAbandon() async {
    let didArchiveGame = ActorIsolated(false)

    let store = TestStore(
      initialState: AppState(game: update(.mock) { $0.gameMode = .timed }),
      reducer: appReducer,
      environment: update(.unimplemented) {
        $0.audioPlayer.stop = { _ in }
        $0.database.saveGame = { _ in await didArchiveGame.setValue(true) }
        $0.mainQueue = .immediate
      }
    )

    await store.send(.currentGame(.game(.menuButtonTapped))) {
      try XCTUnwrap(&$0.game) {
        $0.bottomMenu = .init(
          title: .init("Solo"),
          message: nil,
          buttons: [
            .init(
              title: .init("End game"),
              icon: .flag,
              action: .init(action: .endGameButtonTapped, animation: .default)
            )
          ],
          footerButton: .init(
            title: .init("Settings"),
            icon: .init(systemName: "gear"),
            action: .init(action: .settingsButtonTapped, animation: .default)
          ),
          onDismiss: .init(action: .dismissBottomMenu, animation: .default)
        )
      }
    }
    await store.send(.currentGame(.game(.endGameButtonTapped))) {
      try XCTUnwrap(&$0.game) {
        $0.gameOver = GameOverState(
          completedGame: .init(gameState: $0),
          isDemo: false
        )
        $0.bottomMenu = nil
      }
    }
    .finish()

    await didArchiveGame.withValue { XCTAssert($0) }
  }

  func testUnlimitedResume() async {
    let savedGames = SavedGamesState(dailyChallengeUnlimited: nil, unlimited: .mock)
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: update(.didFinishLaunching) {
        $0.fileClient.override(load: savedGamesFileName, savedGames)
      }
    )

    store.dependencies.didFinishLaunching()

    let task = await store.send(.appDelegate(.didFinishLaunching))
    await store.receive(.savedGamesLoaded(.success(savedGames))) {
      $0.home.savedGames = savedGames
    }
    await store.send(.home(.setNavigation(tag: .solo))) {
      $0.home.route = .solo(.init(inProgressGame: .mock))
    }
    await store.send(.home(.solo(.gameButtonTapped(.unlimited)))) {
      $0.game = GameState(inProgressGame: .mock)
    }
    await task.cancel()
  }

  func testTurnBasedAbandon() async {
    let store = TestStore(
      initialState: AppState(
        game: update(.mock) {
          $0.gameContext = .turnBased(
            .init(
              localPlayer: .mock,
              match: .inProgress,
              metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
            )
          )
        },
        home: HomeState(
          savedGames: SavedGamesState(
            dailyChallengeUnlimited: .mock,
            unlimited: .mock
          )
        )
      ),
      reducer: appReducer,
      environment: update(.unimplemented) {
        $0.audioPlayer.stop = { _ in }
      }
    )

    await store.send(.currentGame(.game(.endGameButtonTapped))) {
      try XCTUnwrap(&$0.game) {
        var gameOver = GameOverState(
          completedGame: .init(gameState: $0),
          isDemo: false
        )
        gameOver.turnBasedContext = $0.turnBasedContext
        $0.gameOver = gameOver
      }
    }
  }
}
