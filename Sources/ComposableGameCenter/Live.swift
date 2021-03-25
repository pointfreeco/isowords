import Combine
import CombineHelpers
import ComposableArchitecture
import GameKit

extension GameCenterClient {
  public static var live: Self {
    return Self(
      gameCenterViewController: .live,
      localPlayer: .live,
      reportAchievements: { achievements in
        .future { callback in
          GKAchievement.report(achievements) { error in
            callback(error.map(Result.failure) ?? .success(()))
          }
        }
      },
      showNotificationBanner: { request in
        .future { callback in
          GKNotificationBanner.show(withTitle: request.title, message: request.message) {
            callback(.success(()))
          }
        }
      },
      turnBasedMatch: .live,
      turnBasedMatchmakerViewController: .live
    )
  }
}

extension GameCenterViewControllerClient {
  public static let live = Self(
    present: .run { subscriber in
      final class Delegate: NSObject, GKGameCenterControllerDelegate {
        let subscriber: Effect<DelegateEvent, Never>.Subscriber

        init(subscriber: Effect<DelegateEvent, Never>.Subscriber) {
          self.subscriber = subscriber
        }

        func gameCenterViewControllerDidFinish(
          _ gameCenterViewController: GKGameCenterViewController
        ) {
          self.subscriber.send(.didFinish)
          self.subscriber.send(completion: .finished)
        }
      }

      let viewController = GKGameCenterViewController()
      Self.viewController = viewController
      var delegate: Optional = Delegate(subscriber: subscriber)
      viewController.gameCenterDelegate = delegate
      viewController.present()

      return AnyCancellable {
        delegate = nil
        viewController.dismiss()
      }
    },
    dismiss: .fireAndForget {
      guard let viewController = Self.viewController else { return }
      viewController.dismiss()
      Self.viewController = nil
    }
  )

  private static var viewController: GKGameCenterViewController?
}

extension LocalPlayerClient {
  public static var live: Self {
    var localPlayer: GKLocalPlayer { .local }

    return Self(
      authenticate:
        Effect
        .run { subscriber in
          localPlayer.authenticateHandler = { viewController, error in
            subscriber.send(error.map { $0 as NSError })
            if viewController != nil {
              Self.viewController = viewController
            }
          }
          return AnyCancellable {
            Self.viewController?.dismiss()
            Self.viewController = nil
          }
        }
        .shareReplay(1)
        .eraseToEffect(),
      listener:
        Effect
        .run { subscriber in
          class Listener: NSObject, GKLocalPlayerListener {
            let subscriber: Effect<ListenerEvent, Never>.Subscriber

            init(subscriber: Effect<ListenerEvent, Never>.Subscriber) {
              self.subscriber = subscriber
            }

            func player(
              _ player: GKPlayer, didComplete challenge: GKChallenge,
              issuedByFriend friendPlayer: GKPlayer
            ) {
              self.subscriber.send(
                .challenge(.didComplete(challenge, issuedByFriend: friendPlayer)))
            }
            func player(_ player: GKPlayer, didReceive challenge: GKChallenge) {
              self.subscriber.send(.challenge(.didReceive(challenge)))
            }
            func player(
              _ player: GKPlayer, issuedChallengeWasCompleted challenge: GKChallenge,
              byFriend friendPlayer: GKPlayer
            ) {
              self.subscriber.send(
                .challenge(.issuedChallengeWasCompleted(challenge, byFriend: friendPlayer)))
            }
            func player(_ player: GKPlayer, wantsToPlay challenge: GKChallenge) {
              self.subscriber.send(.challenge(.wantsToPlay(challenge)))
            }
            func player(_ player: GKPlayer, didAccept invite: GKInvite) {
              self.subscriber.send(.invite(.didAccept(invite)))
            }
            func player(
              _ player: GKPlayer, didRequestMatchWithRecipients recipientPlayers: [GKPlayer]
            ) {
              self.subscriber.send(.invite(.didRequestMatchWithRecipients(recipientPlayers)))
            }
            func player(_ player: GKPlayer, didModifySavedGame savedGame: GKSavedGame) {
              self.subscriber.send(.savedGame(.didModifySavedGame(savedGame)))
            }
            func player(_ player: GKPlayer, hasConflictingSavedGames savedGames: [GKSavedGame]) {
              self.subscriber.send(.savedGame(.hasConflictingSavedGames(savedGames)))
            }
            func player(
              _ player: GKPlayer, didRequestMatchWithOtherPlayers playersToInvite: [GKPlayer]
            ) {
              self.subscriber.send(.turnBased(.didRequestMatchWithOtherPlayers(playersToInvite)))
            }
            func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {
              self.subscriber.send(.turnBased(.matchEnded(.init(rawValue: match))))
            }
            func player(
              _ player: GKPlayer, receivedExchangeCancellation exchange: GKTurnBasedExchange,
              for match: GKTurnBasedMatch
            ) {
              self.subscriber.send(
                .turnBased(.receivedExchangeCancellation(exchange, match: .init(rawValue: match))))
            }
            func player(
              _ player: GKPlayer, receivedExchangeReplies replies: [GKTurnBasedExchangeReply],
              forCompletedExchange exchange: GKTurnBasedExchange, for match: GKTurnBasedMatch
            ) {
              self.subscriber.send(
                .turnBased(.receivedExchangeReplies(replies, match: .init(rawValue: match))))
            }
            func player(
              _ player: GKPlayer, receivedExchangeRequest exchange: GKTurnBasedExchange,
              for match: GKTurnBasedMatch
            ) {
              self.subscriber.send(
                .turnBased(.receivedExchangeRequest(exchange, match: .init(rawValue: match))))
            }
            func player(
              _ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch,
              didBecomeActive: Bool
            ) {
              self.subscriber.send(
                .turnBased(
                  .receivedTurnEventForMatch(
                    .init(rawValue: match), didBecomeActive: didBecomeActive)))
            }
            func player(_ player: GKPlayer, wantsToQuitMatch match: GKTurnBasedMatch) {
              self.subscriber.send(.turnBased(.wantsToQuitMatch(.init(rawValue: match))))
            }
          }

          let id = UUID()
          let listener = Listener(subscriber: subscriber)
          Self.listeners[id] = listener
          localPlayer.register(listener)

          return AnyCancellable {
            localPlayer.unregisterListener(Self.listeners[id]!)
            Self.listeners[id] = nil
          }
        }
        .eraseToEffect(),
      localPlayer: { .init(rawValue: localPlayer) },
      presentAuthenticationViewController: .run { _ in
        Self.viewController?.present()
        return AnyCancellable {
          Self.viewController?.dismiss()
          Self.viewController = nil
        }
      }
    )
  }

  private static var listeners: [UUID: GKLocalPlayerListener] = [:]
  private static var viewController: ViewController?
}

extension TurnBasedMatchClient {
  public static let live = Self(
    endMatchInTurn: { request in
      .future { callback in
        GKTurnBasedMatch.load(withID: request.matchId.rawValue) { match, error in
          guard let match = match else {
            callback(.failure(error ?? invalidStateError))
            return
          }
          match.setLocalizableMessageWithKey(
            request.message.key, arguments: request.message.arguments
          )
          match.participants.forEach { participant in
            if participant.status == .active, let player = participant.player {
              let matchOutcome =
                request.localPlayerMatchOutcome == .tied
                ? .tied
                : player.gamePlayerID == request.localPlayerId.rawValue
                  ? request.localPlayerMatchOutcome
                  : request.localPlayerMatchOutcome == .won
                    ? .lost
                    : .won
              participant.matchOutcome = matchOutcome
              if match.currentParticipant == participant {
                match.currentParticipant?.matchOutcome = matchOutcome
              }
            }
          }
          match.endMatchInTurn(withMatch: request.matchData) { error in
            callback(error.map(Result.failure) ?? .success(()))
          }
        }
      }
    },
    endTurn: { request in
      .future { callback in
        GKTurnBasedMatch.load(withID: request.matchId.rawValue) { match, error in
          guard let match = match else {
            callback(.failure(error ?? invalidStateError))
            return
          }
          match.setLocalizableMessageWithKey(
            request.message.key, arguments: request.message.arguments
          )
          match.endTurn(
            withNextParticipants: match.participants
              .filter { $0.player?.gamePlayerID != match.currentParticipant?.player?.gamePlayerID },
            turnTimeout: GKTurnTimeoutDefault,
            match: request.matchData
          ) { error in callback(error.map(Result.failure) ?? .success(())) }
        }
      }
    },
    load: { matchId in
      .future { callback in
        GKTurnBasedMatch.load(withID: matchId.rawValue) { match, error in
          callback(
            match.map { .success(.init(rawValue: $0)) }
              ?? .failure(error ?? invalidStateError)
          )
        }
      }
    },
    loadMatches: {
      .future { callback in
        GKTurnBasedMatch.loadMatches { matches, error in
          callback(
            matches.map { .success($0.map(TurnBasedMatch.init(rawValue:))) }
              ?? .failure(error ?? invalidStateError)
          )
        }
      }
    },
    participantQuitInTurn: { matchId, matchData in
      .future { callback in
        GKTurnBasedMatch.load(withID: matchId.rawValue) { match, error in
          guard let match = match else {
            callback(.success(error))
            return
          }
          match.participantQuitInTurn(
            with: .quit,
            nextParticipants: match.participants
              .filter { $0.player?.gamePlayerID != match.currentParticipant?.player?.gamePlayerID },
            turnTimeout: 0,
            match: matchData
          ) { callback(.success($0)) }
        }
      }
    },
    participantQuitOutOfTurn: { matchId in
      .future { callback in
        GKTurnBasedMatch.load(withID: matchId.rawValue) { match, error in
          guard let match = match else {
            callback(.success(error))
            return
          }
          match.participantQuitOutOfTurn(with: .quit) {
            callback(.success($0))
          }
        }
      }
    },
    rematch: { matchId in
      .future { callback in
        GKTurnBasedMatch.load(withID: matchId.rawValue) { match, error in
          guard let match = match else {
            callback(.failure(error ?? invalidStateError))
            return
          }
          match.rematch { match, error in
            callback(
              match.map { .success(.init(rawValue: $0)) }
                ?? .failure(error ?? invalidStateError)
            )
          }
        }
      }
    },
    remove: { match in
      .future { callback in
        guard let turnBasedMatch = match.rawValue
        else {
          struct RawValueWasNil: Error {}
          callback(.failure(RawValueWasNil()))
          return
        }
        turnBasedMatch.remove { error in
          callback(
            error.map(Result.failure)
              ?? .success(())
          )
        }
      }
    },
    saveCurrentTurn: { matchId, matchData in
      .future { callback in
        GKTurnBasedMatch.load(withID: matchId.rawValue) { match, error in
          guard let match = match else {
            callback(.failure(error ?? invalidStateError))
            return
          }
          match.saveCurrentTurn(withMatch: matchData) { error in
            callback(error.map(Result.failure) ?? .success(()))
          }
        }
      }
    },
    sendReminder: { request in
      .future { callback in
        GKTurnBasedMatch.load(withID: request.matchId.rawValue) { match, error in
          guard let match = match else {
            callback(.failure(error ?? invalidStateError))
            return
          }
          match.sendReminder(
            to: request.participantsAtIndices.map { match.participants[$0] },
            localizableMessageKey: request.message.key,
            arguments: request.message.arguments
          ) { error in callback(error.map(Result.failure) ?? .success(())) }
        }
      }
    }
  )
}

extension TurnBasedMatchmakerViewControllerClient {
  public static let live = Self(
    _present: { showExistingMatches in
      .run { subscriber in
        class Delegate: NSObject, GKTurnBasedMatchmakerViewControllerDelegate {
          let subscriber: Effect<DelegateEvent, Never>.Subscriber

          init(subscriber: Effect<DelegateEvent, Never>.Subscriber) {
            self.subscriber = subscriber
          }

          func turnBasedMatchmakerViewControllerWasCancelled(
            _ viewController: GKTurnBasedMatchmakerViewController
          ) {
            self.subscriber.send(.wasCancelled)
            self.subscriber.send(completion: .finished)
          }

          func turnBasedMatchmakerViewController(
            _ viewController: GKTurnBasedMatchmakerViewController, didFailWithError error: Error
          ) {
            self.subscriber.send(.didFailWithError(error as NSError))
            self.subscriber.send(completion: .finished)
          }
        }

        let matchRequest = GKMatchRequest()
        matchRequest.inviteMessage = "Let's play isowords!"
        matchRequest.maxPlayers = 2
        matchRequest.minPlayers = 2
        matchRequest.recipientResponseHandler = { player, response in

        }

        let viewController = GKTurnBasedMatchmakerViewController(matchRequest: matchRequest)
        viewController.showExistingMatches = showExistingMatches
        Self.viewController = viewController
        var delegate: Optional = Delegate(subscriber: subscriber)
        viewController.turnBasedMatchmakerDelegate = delegate
        viewController.present()

        return AnyCancellable {
          delegate = nil
          viewController.dismiss()
          Self.viewController = nil
        }
      }
    },
    dismiss: .fireAndForget {
      guard let viewController = Self.viewController else { return }
      viewController.dismiss()
      Self.viewController = nil
    }
  )

  private static var viewController: GKTurnBasedMatchmakerViewController?
}

private let invalidStateError = NSError(domain: "co.pointfree", code: -1)
