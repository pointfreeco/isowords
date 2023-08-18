import BottomMenu
import ClientModels
import Combine
import ComposableArchitecture
import ComposableUserNotifications
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
  func testUnlimitedSaveAndQuit() async throws {
    let saves = ActorIsolated<[Data]>([])

    let store = TestStore(
      initialState: AppReducer.State(
        home: .init(destination: .solo(.init()))
      )
    ) {
      AppReducer()
    }

    store.dependencies.audioPlayer.play = { _ in }
    store.dependencies.audioPlayer.stop = { _ in }
    store.dependencies.dictionary.contains = { word, _ in word == "CAB" }
    store.dependencies.dictionary.randomCubes = { _ in .mock }
    store.dependencies.feedbackGenerator = .noop
    store.dependencies.fileClient.save = { @Sendable _, data in await saves.withValue { $0.append(data) } }
    store.dependencies.mainRunLoop = .immediate
    store.dependencies.mainQueue = .immediate

    let index = LatticePoint(x: .two, y: .two, z: .two)
    let C = IndexedCubeFace(index: index, side: .top)
    let A = IndexedCubeFace(index: index, side: .left)
    let B = IndexedCubeFace(index: index, side: .right)

    await store.send(.home(.destination(.presented(.solo(.gameButtonTapped(.unlimited)))))) {
      $0.destination = .game(
        Game.State(
          cubes: .mock,
          gameContext: .solo,
          gameCurrentTime: RunLoop.immediate.now.date,
          gameMode: .unlimited,
          gameStartTime: RunLoop.immediate.now.date
        )
      )
      $0.home.savedGames.unlimited = $0.$destination[case: /AppReducer.Destination.State.game]
        .map(InProgressGame.init)
    }
    await store.send(.destination(.presented(.game(.tap(.began, C))))) {
      $0.$destination[case: /AppReducer.Destination.State.game]?.optimisticallySelectedFace = C
      $0.$destination[case: /AppReducer.Destination.State.game]?.selectedWord = [C]
    }
    await store.send(.destination(.presented(.game(.tap(.ended, C))))) {
      $0.$destination[case: /AppReducer.Destination.State.game]?.optimisticallySelectedFace = nil
    }
    await store.send(.destination(.presented(.game(.tap(.began, A))))) {
      $0.$destination[case: /AppReducer.Destination.State.game]?.optimisticallySelectedFace = A
      $0.$destination[case: /AppReducer.Destination.State.game]?.selectedWord = [C, A]
    }
    await store.send(.destination(.presented(.game(.tap(.ended, A))))) {
      $0.$destination[case: /AppReducer.Destination.State.game]?.optimisticallySelectedFace = nil
    }
    await store.send(.destination(.presented(.game(.tap(.began, B))))) {
      $0.$destination[case: /AppReducer.Destination.State.game]?.optimisticallySelectedFace = B
      $0.$destination[case: /AppReducer.Destination.State.game]?.selectedWord = [C, A, B]
      $0.$destination[case: /AppReducer.Destination.State.game]?.selectedWordIsValid = true
    }
    await store.send(.destination(.presented(.game(.tap(.ended, B))))) {
      $0.$destination[case: /AppReducer.Destination.State.game]?.optimisticallySelectedFace = nil
    }
    await store.send(.destination(.presented(.game(.submitButtonTapped(reaction: nil))))) {
      let game = try XCTUnwrap($0.$destination[case: /AppReducer.Destination.State.game])
      $0.$destination[case: /AppReducer.Destination.State.game]?.moves = [
        .init(
          playedAt: RunLoop.immediate.now.date,
          playerIndex: nil,
          reactions: nil,
          score: 27,
          type: .playedWord(game.selectedWord)
        )
      ]
      $0.$destination[case: /AppReducer.Destination.State.game]?.selectedWord = []
      $0.$destination[case: /AppReducer.Destination.State.game]?.selectedWordIsValid = false
      $0.$destination[case: /AppReducer.Destination.State.game]?.cubes[index].left.useCount = 1
      $0.$destination[case: /AppReducer.Destination.State.game]?.cubes[index].right.useCount = 1
      $0.$destination[case: /AppReducer.Destination.State.game]?.cubes[index].top.useCount = 1
      $0.home.savedGames.unlimited = $0.$destination[case: /AppReducer.Destination.State.game]
        .map(InProgressGame.init)
    }
    await store.send(.destination(.presented(.game(.menuButtonTapped)))) {
      $0.$destination[case: /AppReducer.Destination.State.game]?.destination = .bottomMenu(
        .init(
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
          )
        )
      )
    }
    await store.send(
      .destination(.presented(.game(.destination(.presented(.bottomMenu(.exitButtonTapped))))))
    ) {
      let game = try XCTUnwrap($0.destination, case: /AppReducer.Destination.State.game)
      $0.home.savedGames.unlimited = InProgressGame(gameState: game)
      $0.destination = nil
    }
    try await saves.withValue {
      XCTAssertNoDifference(2, $0.count)
      XCTAssertNoDifference(
        try JSONDecoder().decode(SavedGamesState.self, from: $0.last!),
        store.state.home.savedGames
      )
    }
  }

  func testUnlimitedAbandon() async throws {
    let didArchiveGame = ActorIsolated(false)
    let saves = ActorIsolated<[Data]>([])

    let store = TestStore(
      initialState: AppReducer.State(
        destination: .game(update(.mock) { $0.gameMode = .unlimited }),
        home: Home.State(savedGames: SavedGamesState(unlimited: .mock))
      )
    ) {
      AppReducer()
    } withDependencies: {
      $0.audioPlayer.stop = { _ in }
      $0.database.saveGame = { _ in await didArchiveGame.setValue(true) }
      $0.gameCenter.localPlayer.localPlayer = { .notAuthenticated }
      $0.fileClient.save = { @Sendable _, data in await saves.withValue { $0.append(data) } }
      $0.mainQueue = .immediate
    }

    await store.send(.destination(.presented(.game(.menuButtonTapped)))) {
      $0.$destination[case: /AppReducer.Destination.State.game]?.destination = .bottomMenu(
        .init(
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
          )
        )
      )
    }
    await store.send(
      .destination(.presented(.game(.destination(.presented(.bottomMenu(.endGameButtonTapped))))))
    ) {
      let game = try XCTUnwrap($0.destination, case: /AppReducer.Destination.State.game)
      $0.$destination[case: /AppReducer.Destination.State.game]?.destination = .gameOver(
        GameOver.State(
          completedGame: .init(gameState: game),
          isDemo: false
        )
      )
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
      initialState: AppReducer.State(destination: .game(update(.mock) { $0.gameMode = .timed }))
    ) {
      AppReducer()
    } withDependencies: {
      $0.audioPlayer.stop = { _ in }
      $0.database.saveGame = { _ in await didArchiveGame.setValue(true) }
      $0.mainQueue = .immediate
    }

    await store.send(.destination(.presented(.game(.menuButtonTapped)))) {
      $0.$destination[case: /AppReducer.Destination.State.game]?.destination = .bottomMenu(
        .init(
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
          )
        )
      )
    }
    await store.send(
      .destination(.presented(.game(.destination(.presented(.bottomMenu(.endGameButtonTapped))))))
    ) {
      let game = try XCTUnwrap($0.destination, case: /AppReducer.Destination.State.game)
      $0.$destination[case: /AppReducer.Destination.State.game]?.destination = .gameOver(
        GameOver.State(
          completedGame: .init(gameState: game),
          isDemo: false
        )
      )
    }

    await didArchiveGame.withValue { XCTAssert($0) }
  }

  func testUnlimitedResume() async {
    let savedGames = SavedGamesState(dailyChallengeUnlimited: nil, unlimited: .mock)
    let store = TestStore(
      initialState: AppReducer.State()
    ) {
      AppReducer()
    } withDependencies: {
      $0.audioPlayer.secondaryAudioShouldBeSilencedHint = { false }
      $0.audioPlayer.setGlobalVolumeForMusic = { _ in }
      $0.audioPlayer.setGlobalVolumeForSoundEffects = { _ in }
      $0.applicationClient.setUserInterfaceStyle = { _ in }
    }

    store.dependencies.didFinishLaunching()
    store.dependencies.fileClient.override(load: savedGamesFileName, savedGames)

    let task = await store.send(.appDelegate(.didFinishLaunching))
    await store.receive(.savedGamesLoaded(.success(savedGames))) {
      $0.home.savedGames = savedGames
    }
    await store.send(.home(.soloButtonTapped)) {
      $0.home.destination = .solo(.init(inProgressGame: .mock))
    }
    await store.send(.home(.destination(.presented(.solo(.gameButtonTapped(.unlimited)))))) {
      $0.destination = .game(Game.State(inProgressGame: .mock))
    }
    await task.cancel()
  }

  func testTurnBasedAbandon() async {
    let store = TestStore(
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
    }

    store.dependencies.audioPlayer.stop = { _ in }

    await store.send(.destination(.presented(.game(.menuButtonTapped)))) {
      let game = try XCTUnwrap($0.destination, case: /AppReducer.Destination.State.game)
      $0.$destination[case: /AppReducer.Destination.State.game]?.destination = .bottomMenu(
        .gameMenu(state: game)
      )
    }
    await store.send(
      .destination(.presented(.game(.destination(.presented(.bottomMenu(.endGameButtonTapped))))))
    ) {
      let game = try XCTUnwrap($0.destination, case: /AppReducer.Destination.State.game)
      var gameOver = GameOver.State(
        completedGame: .init(gameState: game),
        isDemo: false
      )
      gameOver.turnBasedContext = game.turnBasedContext
      $0.$destination[case: /AppReducer.Destination.State.game]?.destination = .gameOver(gameOver)
    }
  }
}
