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
import Prelude
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

class PersistenceTests: XCTestCase {
  func testUnlimitedSaveAndQuit() {
    var saves: [Data] = []

    let store = TestStore(
      initialState: .init(
        home: .init(route: .solo(.init()))
      ),
      reducer: appReducer,
      environment: update(.failing) {
        $0.audioPlayer.play = { _ in .none }
        $0.backgroundQueue = DispatchQueue.immediateScheduler.eraseToAnyScheduler()
        $0.dictionary.contains = { word, _ in word == "CAB" }
        $0.dictionary.randomCubes = { _ in .mock }
        $0.feedbackGenerator = .noop
        $0.fileClient.save = { _, data in
          saves.append(data)
          return .none
        }
        $0.mainRunLoop = RunLoop.immediateScheduler.eraseToAnyScheduler()
      }
    )

    let index = LatticePoint(x: .two, y: .two, z: .two)
    let C = IndexedCubeFace(index: index, side: .top)
    let A = IndexedCubeFace(index: index, side: .left)
    let B = IndexedCubeFace(index: index, side: .right)

    store.send(.home(.solo(.gameButtonTapped(.unlimited)))) {
      $0.game = GameState(
        cubes: .mock,
        gameContext: .solo,
        gameCurrentTime: RunLoop.immediateScheduler.now.date,
        gameMode: .unlimited,
        gameStartTime: RunLoop.immediateScheduler.now.date
      )
      $0.home.savedGames.unlimited = $0.game.map(InProgressGame.init)
    }
    store.send(.currentGame(.game(.tap(.began, C)))) {
      try XCTUnwrap(&$0.game) {
        $0.optimisticallySelectedFace = C
        $0.selectedWord = [C]
      }
    }
    store.send(.currentGame(.game(.tap(.ended, C)))) {
      try XCTUnwrap(&$0.game) {
        $0.optimisticallySelectedFace = nil
      }
    }
    store.send(.currentGame(.game(.tap(.began, A)))) {
      try XCTUnwrap(&$0.game) {
        $0.optimisticallySelectedFace = A
        $0.selectedWord = [C, A]
      }
    }
    store.send(.currentGame(.game(.tap(.ended, A)))) {
      try XCTUnwrap(&$0.game) {
        $0.optimisticallySelectedFace = nil
      }
    }
    store.send(.currentGame(.game(.tap(.began, B)))) {
      try XCTUnwrap(&$0.game) {
        $0.optimisticallySelectedFace = B
        $0.selectedWord = [C, A, B]
        $0.selectedWordIsValid = true
      }
    }
    store.send(.currentGame(.game(.tap(.ended, B)))) {
      try XCTUnwrap(&$0.game) {
        $0.optimisticallySelectedFace = nil
      }
    }
    store.send(.currentGame(.game(.submitButtonTapped(nil)))) {
      try XCTUnwrap(&$0.game) {
        $0.moves = [
          .init(
            playedAt: RunLoop.immediateScheduler.now.date,
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
    store.send(.currentGame(.game(.menuButtonTapped))) {
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
    store.send(.currentGame(.game(.exitButtonTapped))) { appState in
      try XCTUnwrap(&appState.game) { game in
        appState.home.savedGames.unlimited = InProgressGame(gameState: game)
      }
      appState.game = nil
      XCTAssertEqual(2, saves.count)
      XCTAssertEqual(saves.last!, try JSONEncoder().encode(appState.home.savedGames))
    }
  }

  func testUnlimitedAbandon() throws {
    var didArchiveGame = false
    var saves: [Data] = []

    let store = TestStore(
      initialState: AppState(
        game: update(.mock) { $0.gameMode = .unlimited },
        home: HomeState(savedGames: SavedGamesState(unlimited: .mock))
      ),
      reducer: appReducer,
      environment: update(.failing) {
        $0.audioPlayer.stop = { _ in .none }
        $0.backgroundQueue = DispatchQueue.immediateScheduler.eraseToAnyScheduler()
        $0.database.saveGame = { _ in
          didArchiveGame = true
          return .none
        }
        $0.gameCenter.localPlayer.localPlayer = { .notAuthenticated }
        $0.fileClient.save = { _, data in
          saves.append(data)
          return .none
        }
      }
    )

    store.send(.currentGame(.game(.menuButtonTapped))) {
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
    store.send(.currentGame(.game(.endGameButtonTapped))) {
      try XCTUnwrap(&$0.game) {
        $0.gameOver = GameOverState(
          completedGame: .init(gameState: $0),
          isDemo: false
        )
        $0.bottomMenu = nil
      }
      $0.home.savedGames.unlimited = nil
    }

    XCTAssertEqual(didArchiveGame, true)
    XCTAssertEqual(saves, [try JSONEncoder().encode(SavedGamesState())])
  }

  func testTimedAbandon() {
    var didArchiveGame = false

    let store = TestStore(
      initialState: AppState(game: update(.mock) { $0.gameMode = .timed }),
      reducer: appReducer,
      environment: update(.failing) {
        $0.audioPlayer.stop = { _ in .none }
        $0.database.saveGame = { _ in
          didArchiveGame = true
          return .none
        }
      }
    )

    store.send(.currentGame(.game(.menuButtonTapped))) {
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
    store.send(.currentGame(.game(.endGameButtonTapped))) {
      try XCTUnwrap(&$0.game) {
        $0.gameOver = GameOverState(
          completedGame: .init(gameState: $0),
          isDemo: false
        )
        $0.bottomMenu = nil
      }
    }

    XCTAssertEqual(didArchiveGame, true)
  }

  func testUnlimitedResume() {
    let savedGames = SavedGamesState(dailyChallengeUnlimited: nil, unlimited: .mock)
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: update(.didFinishLaunching) {
        $0.fileClient.override(load: savedGamesFileName, .init(value: savedGames))
      }
    )

    store.send(.appDelegate(.didFinishLaunching))
    store.receive(.savedGamesLoaded(.success(savedGames))) {
      $0.home.savedGames = savedGames
    }
    store.send(.home(.setNavigation(tag: .solo))) {
      $0.home.route = .solo(.init(inProgressGame: .mock))
    }
    store.send(.home(.solo(.gameButtonTapped(.unlimited)))) {
      $0.game = GameState(inProgressGame: .mock)
    }
  }
}
