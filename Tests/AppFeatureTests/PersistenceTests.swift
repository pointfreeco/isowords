import BottomMenu
import ClientModels
import ComposableArchitecture
import ComposableUserNotifications
import ConcurrencyExtras
import CustomDump
import Dependencies
import FeedbackGeneratorClient
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
  override func invokeTest() {
    withMainSerialExecutor {
      super.invokeTest()
    }
  }

  func testUnlimitedSaveAndQuit() async throws {
    let saves = LockIsolated<[Data]>([])

    let store = withDependencies {
      $0.didFinishLaunching()
      $0.dictionary.contains = { word, _ in word == "CAB" }
      $0.dictionary.randomCubes = { _ in .mock }
      $0.fileClient.save = { @Sendable _, data in saves.withValue { $0.append(data) } }
    } operation: {
      TestStore(
        initialState: AppReducer.State(
          home: .init(destination: .solo(.init()))
        )
      ) {
        AppReducer()
          .environment(\.continuousClock, TestClock())
      }
    }

    let index = LatticePoint(x: .two, y: .two, z: .two)
    let C = IndexedCubeFace(index: index, side: .top)
    let A = IndexedCubeFace(index: index, side: .left)
    let B = IndexedCubeFace(index: index, side: .right)

    let newGame = Game.State(
      cubes: .mock,
      gameContext: .solo,
      gameCurrentTime: Date(timeIntervalSinceReferenceDate: 0),
      gameMode: .unlimited,
      gameStartTime: Date(timeIntervalSinceReferenceDate: 0)
    )
    await store.send(to: \.home.destination?.solo, .gameButtonTapped(.unlimited))?.value
    store.expect {
      $0.destination = .game(snap(newGame))
      $0.home.activeGames.savedGames.unlimited = InProgressGame(gameState: newGame)
    }
    try store.send(to: \.destination?.game, .tap(.began, C)) {
      try $0.destination.modify(\.game) {
        $0.optimisticallySelectedFace = C
        $0.selectedWord = [C]
      }
    }
    try store.send(to: \.destination?.game, .tap(.ended, C)) {
      try $0.destination.modify(\.game) {
        $0.optimisticallySelectedFace = nil
      }
    }
    try store.send(to: \.destination?.game, .tap(.began, A)) {
      try $0.destination.modify(\.game) {
        $0.optimisticallySelectedFace = A
        $0.selectedWord = [C, A]
      }
    }
    try store.send(to: \.destination?.game, .tap(.ended, A)) {
      try $0.destination.modify(\.game) {
        $0.optimisticallySelectedFace = nil
      }
    }
    try store.send(to: \.destination?.game, .tap(.began, B)) {
      try $0.destination.modify(\.game) {
        $0.optimisticallySelectedFace = B
        $0.selectedWord = [C, A, B]
        $0.selectedWordIsValid = true
      }
    }
    try store.send(to: \.destination?.game, .tap(.ended, B)) {
      try $0.destination.modify(\.game) {
        $0.optimisticallySelectedFace = nil
      }
    }
    var playedGame = newGame
    playedGame.moves = [
      .init(
        playedAt: Date(timeIntervalSinceReferenceDate: 0),
        playerIndex: nil,
        reactions: nil,
        score: 27,
        type: .playedWord([C, A, B])
      )
    ]
    playedGame.cubes[index].left.useCount = 1
    playedGame.cubes[index].right.useCount = 1
    playedGame.cubes[index].top.useCount = 1
    try store.send(to: \.destination?.game, .submitButtonTapped(reaction: nil)) {
      try $0.destination.modify(\.game) {
        $0.moves = playedGame.moves
        $0.selectedWord = []
        $0.selectedWordIsValid = false
        $0.cubes = playedGame.cubes
      }
      $0.home.activeGames.savedGames.unlimited = InProgressGame(gameState: playedGame)
    }
    try store.send(to: \.destination?.game, .menuButtonTapped) {
      try $0.destination.modify(\.game) {
        $0.destination = .bottomMenu(
          snap(
            BottomMenuState<Game.Destination.BottomMenu>(
              title: Text(verbatim: "Solo"),
              message: nil,
              buttons: [
                .init(
                  title: Text("Main menu"),
                  icon: .exit,
                  action: .init(action: .exitButtonTapped, animation: .default)
                ),
                .init(
                  title: Text("End game"),
                  icon: .flag,
                  action: .init(action: .endGameButtonTapped, animation: .default)
                ),
              ],
              footerButton: .init(
                title: Text("Settings"),
                icon: Image(systemName: "gear"),
                action: .init(action: .settingsButtonTapped, animation: .default)
              )
            )
          )
        )
      }
    }
    try await store.send(to: \.destination?.game, .destination(.bottomMenu(.exitButtonTapped))) {
      try $0.destination.modify(\.game) {
        $0.destination = nil
      }
    }?.value
    store.expect {
      $0.destination = nil
    }
    expectNoDifference(saves.value.count, 2)
    expectNoDifference(
      try JSONDecoder().decode(SavedGamesState.self, from: saves.value.last!),
      store.state.home.savedGames
    )

    await store.dismount()
  }

  func testUnlimitedAbandon() async throws {
    let didArchiveGame = LockIsolated(false)
    let saves = LockIsolated<[Data]>([])

    let store = try withDependencies {
      $0.didFinishLaunching()
      $0.database.saveGame = { _ in didArchiveGame.setValue(true) }
      $0.fileClient.save = { @Sendable _, data in saves.withValue { $0.append(data) } }
    } operation: {
      try TestStore(
        initialState: AppReducer.State(
          destination: .game(update(.mock) { $0.gameMode = .unlimited }),
          home: Home.State(savedGames: SavedGamesState(unlimited: .mock))
        )
      ) {
        AppReducer()
          .environment(\.continuousClock, TestClock())
      } changes: {
        try $0.destination.modify(\.game) {
          $0.gameCurrentTime = Date(timeIntervalSinceReferenceDate: 0)
        }
      }
    }

    let game = try XCTUnwrap(store.state.destination?.game)
    try store.send(to: \.destination?.game, .menuButtonTapped) {
      try $0.destination.modify(\.game) {
        $0.destination = .bottomMenu(snap(BottomMenuState.gameMenu(state: game)))
      }
    }
    try store.send(to: \.destination?.game, .destination(.bottomMenu(.endGameButtonTapped))) {
      try $0.destination.modify(\.game) {
        $0.destination = .gameOver(
          snap(
            GameOver.State(
              completedGame: .init(gameState: game),
              isDemo: false
            )
          )
        )
      }
      $0.home.activeGames.savedGames.unlimited = nil
    }
    await Task.megaYield()
    store.expect {
      $0.destination = nil
    }

    XCTAssert(didArchiveGame.value)
    expectNoDifference(saves.value, [try JSONEncoder().encode(SavedGamesState())])

    await store.dismount()
  }

  func testTimedAbandon() async throws {
    let didArchiveGame = LockIsolated(false)

    let store = try withDependencies {
      $0.didFinishLaunching()
      $0.database.saveGame = { _ in didArchiveGame.setValue(true) }
    } operation: {
      try TestStore(
        initialState: AppReducer.State(destination: .game(update(.mock) { $0.gameMode = .timed }))
      ) {
        AppReducer()
          .environment(\.continuousClock, TestClock())
      } changes: {
        try $0.destination.modify(\.game) {
          $0.gameCurrentTime = Date(timeIntervalSinceReferenceDate: 0)
        }
      }
    }

    let game = try XCTUnwrap(store.state.destination?.game)
    try store.send(to: \.destination?.game, .menuButtonTapped) {
      try $0.destination.modify(\.game) {
        $0.destination = .bottomMenu(
          snap(
            BottomMenuState<Game.Destination.BottomMenu>(
              title: Text(verbatim: "Solo"),
              message: nil,
              buttons: [
                .init(
                  title: Text("End game"),
                  icon: .flag,
                  action: .init(action: .endGameButtonTapped, animation: .default)
                )
              ],
              footerButton: .init(
                title: Text("Settings"),
                icon: Image(systemName: "gear"),
                action: .init(action: .settingsButtonTapped, animation: .default)
              )
            )
          )
        )
      }
    }
    try store.send(to: \.destination?.game, .destination(.bottomMenu(.endGameButtonTapped))) {
      try $0.destination.modify(\.game) {
        $0.destination = .gameOver(
          snap(
            GameOver.State(
              completedGame: .init(gameState: game),
              isDemo: false
            )
          )
        )
      }
    }
    await Task.megaYield()
    store.expect {
      $0.destination = nil
    }

    XCTAssert(didArchiveGame.value)

    await store.dismount()
  }

  func testUnlimitedResume() async throws {
    let savedGames = SavedGamesState(dailyChallengeUnlimited: nil, unlimited: .mock)
    let store = withDependencies {
      $0.didFinishLaunching()
      $0.fileClient.override(load: savedGamesFileName, savedGames)
    } operation: {
      TestStore(initialState: AppReducer.State()) {
        AppReducer()
          .environment(\.continuousClock, TestClock())
      }
    }

    await store.mountTask?.value
    store.expect {
      $0.home.activeGames.savedGames = savedGames
    }
    await store.send(to: \.home, .soloButtonTapped) {
      $0.home.destination = .solo(snap(Solo.State(inProgressGame: .mock)))
    }?.value
    await store.send(to: \.home.destination?.solo, .gameButtonTapped(.unlimited))?.value
    store.expect {
      $0.destination = .game(
        snap(
          update(Game.State(inProgressGame: .mock)) {
            $0.gameCurrentTime = Date(timeIntervalSinceReferenceDate: 0)
          }
        )
      )
    }

    await store.dismount()
  }

  func testTurnBasedAbandon() async throws {
    let store = try withDependencies {
      $0.didFinishLaunching()
      $0.apiClient.currentPlayer = { nil }
    } operation: {
      try TestStore(
        initialState: AppReducer.State(
          destination: .game(
            update(.mock) {
              $0.gameContext = .turnBased(
                .init(
                  localPlayer: .mock,
                  match: .inProgress,
                  metadata: .init(lastOpenedAt: nil, playerIndexToId: [:])
                )
              )
            }
          ),
          home: Home.State(
            savedGames: SavedGamesState(
              dailyChallengeUnlimited: .mock,
              unlimited: .mock
            )
          )
        )
      ) {
        AppReducer()
          .environment(\.continuousClock, TestClock())
      } changes: {
        try $0.destination.modify(\.game) {
          $0.gameCurrentTime = Date(timeIntervalSinceReferenceDate: 0)
        }
      }
    }

    let game = try XCTUnwrap(store.state.destination?.game)
    try store.send(to: \.destination?.game, .menuButtonTapped) {
      try $0.destination.modify(\.game) {
        $0.destination = .bottomMenu(snap(BottomMenuState.gameMenu(state: game)))
      }
    }
    try store.send(to: \.destination?.game, .destination(.bottomMenu(.endGameButtonTapped))) {
      var gameOver = GameOver.State(
        completedGame: .init(gameState: game),
        isDemo: false
      )
      gameOver.turnBasedContext = game.gameContext.turnBased
      try $0.destination.modify(\.game) {
        $0.destination = .gameOver(snap(gameOver))
      }
    }
    await Task.megaYield()
    store.expect {
      $0.destination = nil
    }

    await store.dismount()
  }
}
