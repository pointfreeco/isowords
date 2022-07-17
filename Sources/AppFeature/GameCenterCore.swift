import ClientModels
import ComposableArchitecture
import ComposableGameCenter
import GameFeature
import GameKit
import GameOverFeature
import HomeFeature
import Overture
import SharedModels

public enum GameCenterAction: Equatable {
  case listener(LocalPlayerClient.ListenerEvent)
  case rematchResponse(Result<TurnBasedMatch, NSError>)
  case turnBasedMatchReloaded(Result<TurnBasedMatch, NSError>)
}

extension Reducer where State == AppState, Action == AppAction, Environment == AppEnvironment {
  func gameCenter() -> Self {
    self
      .combined(
        with: Reducer { state, action, environment in

          func handleTurnBasedMatch(
            _ match: TurnBasedMatch,
            didBecomeActive: Bool
          ) -> Effect<AppAction, Never> {
            guard let matchData = match.matchData, !matchData.isEmpty else {
              let context = TurnBasedContext(
                localPlayer: environment.gameCenter.localPlayer.localPlayer(),
                match: match,
                metadata: .init(
                  lastOpenedAt: environment.mainRunLoop.now.date,
                  playerIndexToId: [:]
                )
              )
              let game = GameState(
                cubes: environment.dictionary.randomCubes(.en),
                gameContext: .turnBased(context),
                gameCurrentTime: environment.mainRunLoop.now.date,
                gameMode: .unlimited,
                gameStartTime: match.creationDate
              )
              state.currentGame = .init(
                game: game,
                settings: state.home.settings
              )
              return .fireAndForget {
                await environment.gameCenter.turnBasedMatchmakerViewController.dismissAsync()
                try await environment.gameCenter.turnBasedMatch.saveCurrentTurnAsync(
                  match.matchId,
                  Data(
                    turnBasedMatchData: .init(
                      context: context,
                      gameState: game,
                      playerId: environment.apiClient.currentPlayerAsync()?.player.id
                    )
                  )
                )
              }
            }

            guard let turnBasedMatchData = matchData.turnBasedMatchData else {
              return .none
            }

            if didBecomeActive {
              var gameState = GameState(
                gameCurrentTime: environment.mainRunLoop.now.date,
                localPlayer: environment.gameCenter.localPlayer.localPlayer(),
                turnBasedMatch: match,
                turnBasedMatchData: turnBasedMatchData
              )
              gameState.activeGames = state.currentGame.game?.activeGames ?? .init()
              gameState.isGameLoaded = state.game != nil
              // TODO: Reuse game logic
              var isGameOver: Bool {
                match.participants.contains(where: { $0.matchOutcome != .none })
              }
              if match.status == .ended || isGameOver {
                gameState.gameOver = .init(
                  completedGame: CompletedGame(gameState: gameState),
                  isDemo: gameState.isDemo,
                  turnBasedContext: gameState.turnBasedContext
                )
              }
              state.currentGame = .init(
                game: gameState,
                settings: state.home.settings
              )
              return .fireAndForget { [turnBasedMatchData] in
                await environment.gameCenter.turnBasedMatchmakerViewController.dismissAsync()
                if gameState.isYourTurn {
                  var turnBasedMatchData = turnBasedMatchData
                  turnBasedMatchData.metadata.lastOpenedAt = environment.mainRunLoop.now.date
                  try await environment.gameCenter.turnBasedMatch.saveCurrentTurnAsync(
                    match.matchId,
                    Data(turnBasedMatchData: turnBasedMatchData)
                  )
                }
              }
            }

            let context = TurnBasedContext(
              localPlayer: environment.gameCenter.localPlayer.localPlayer(),
              match: match,
              metadata: turnBasedMatchData.metadata
            )
            guard
              state.game?.turnBasedContext?.match.matchId != match.matchId,
              context.currentParticipantIsLocalPlayer,
              match.participants.allSatisfy({ $0.matchOutcome == .none }),
              let lastTurnDate = match.participants.compactMap(\.lastTurnDate).max(),
              lastTurnDate > environment.mainRunLoop.now.date.addingTimeInterval(-60)
            else { return .none }

            return .fireAndForget {
              await environment.gameCenter.showNotificationBannerAsync(
                .init(title: match.message, message: nil)
              )
            }
          }

          switch action {
          case .appDelegate(.didFinishLaunching):
            return .run { send in
              try await environment.gameCenter.localPlayer.authenticateAsync()
              for await event in environment.gameCenter.localPlayer.listenerAsync() {
                await send(.gameCenter(.listener(event)))
              }
            } catch: { _, send in
              await Task.cancel(id: ListenerId())
            }
            .cancellable(id: ListenerId(), cancelInFlight: true)

          case .currentGame(.game(.gameOver(.rematchButtonTapped))):
            guard
              let game = state.game,
              let turnBasedMatch = game.turnBasedContext
            else { return .none }

            state.game = nil

            return environment.gameCenter.turnBasedMatch
              .rematch(turnBasedMatch.match.matchId)
              .receive(on: environment.mainQueue)
              .mapError { $0 as NSError }
              .catchToEffect { .gameCenter(.rematchResponse($0)) }

          case let .gameCenter(.listener(.turnBased(.matchEnded(match)))):
            guard state.game?.turnBasedContext?.match.matchId == match.matchId
            else { return .none }

            guard let turnBasedMatchData = match.matchData?.turnBasedMatchData
            else {
              return .none
            }

            let newGame = GameState(
              gameCurrentTime: environment.mainRunLoop.now.date,
              localPlayer: environment.gameCenter.localPlayer.localPlayer(),
              turnBasedMatch: match,
              turnBasedMatchData: turnBasedMatchData
            )
            state.game = newGame

            return environment.database
              .saveGame(.init(gameState: newGame))
              .fireAndForget()

          case let .gameCenter(
            .listener(.turnBased(.receivedTurnEventForMatch(match, didBecomeActive)))):
            return handleTurnBasedMatch(match, didBecomeActive: didBecomeActive)

          case let .gameCenter(.listener(.turnBased(.wantsToQuitMatch(match)))):
            return environment.gameCenter.turnBasedMatch
              .endMatchInTurn(
                .init(
                  for: match.matchId,
                  matchData: match.matchData ?? Data(),
                  localPlayerId: environment.gameCenter.localPlayer.localPlayer().gamePlayerId,
                  localPlayerMatchOutcome: .quit,
                  message:
                    "\(environment.gameCenter.localPlayer.localPlayer().displayName) forfeited the match."
                )
              )
              .fireAndForget()

          case .gameCenter(.listener):
            return .none

          case let .gameCenter(.rematchResponse(.success(turnBasedMatch))),
            let .home(.multiplayer(.pastGames(.pastGame(_, .delegate(.openMatch(turnBasedMatch)))))):
            return handleTurnBasedMatch(turnBasedMatch, didBecomeActive: true)

          case let .gameCenter(.turnBasedMatchReloaded(.success(turnBasedMatch))):
            if state.game?.turnBasedContext?.match.matchId == turnBasedMatch.matchId {
              state.game?.turnBasedContext?.match = turnBasedMatch
            }
            return .none

          case let .home(.activeGames(.turnBasedGameMenuItemTapped(.rematch(matchId)))):
            return environment.gameCenter.turnBasedMatch.rematch(matchId)
              .receive(on: environment.mainQueue)
              .mapError { $0 as NSError }
              .catchToEffect { .gameCenter(.rematchResponse($0)) }

          default:
            return .none
          }
        })
  }
}

private struct ListenerId: Hashable {}
