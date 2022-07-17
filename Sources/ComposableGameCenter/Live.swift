import Combine
import CombineHelpers
import ComposableArchitecture
import GameKit

@available(iOSApplicationExtension, unavailable)
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
      reportAchievementsAsync: { try await GKAchievement.report($0) },
      showNotificationBanner: { request in
        .future { callback in
          GKNotificationBanner.show(withTitle: request.title, message: request.message) {
            callback(.success(()))
          }
        }
      },
      showNotificationBannerAsync: {
        await GKNotificationBanner.show(withTitle: $0.title, message: $0.message)
      },
      turnBasedMatch: .live,
      turnBasedMatchmakerViewController: .live
    )
  }
}

@available(iOSApplicationExtension, unavailable)
extension GameCenterViewControllerClient {
  public static var live: Self {
    actor Presenter {
      var viewController: GKGameCenterViewController?

      func present() async {
        final class Delegate: NSObject, GKGameCenterControllerDelegate {
          let continuation: AsyncStream<Void>.Continuation

          init(continuation: AsyncStream<Void>.Continuation) {
            self.continuation = continuation
          }

          func gameCenterViewControllerDidFinish(
            _ gameCenterViewController: GKGameCenterViewController
          ) {
            self.continuation.yield()
            self.continuation.finish()
          }
        }

        await self.dismiss()
        let viewController = await GKGameCenterViewController()
        self.viewController = viewController
        _ = await AsyncStream<Void> { continuation in
          Task {
            await MainActor.run {
              let delegate = Delegate(continuation: continuation)
              continuation.onTermination = { _ in
                _ = delegate
              }
              viewController.gameCenterDelegate = delegate
              viewController.present()
            }
          }
        }
        .first(where: { _ in true })
      }

      func dismiss() async {
        guard let viewController = self.viewController else { return }
        await viewController.dismiss()
        self.viewController = nil
      }
    }

    let presenter = Presenter()

    return Self(
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
      presentAsync: { await presenter.present() },
      dismiss: .fireAndForget {
        guard let viewController = Self.viewController else { return }
        viewController.dismiss()
        Self.viewController = nil
      },
      dismissAsync: { await presenter.dismiss() }
    )
  }

  private static var viewController: GKGameCenterViewController?
}

@available(iOSApplicationExtension, unavailable)
extension LocalPlayerClient {
  public static var live: Self {
    var localPlayer: GKLocalPlayer { .local }

    return Self(
      // TODO: Used to use `shareReplay(1)` here. Bring back using some local `SendableState`?
      authenticate: {
        _ = try await AsyncThrowingStream<Void, Error> { continuation in
          localPlayer.authenticateHandler = { viewController, error in
            if let error = error {
              continuation.finish(throwing: error)
              return
            }
            continuation.finish()
            if viewController != nil {
              Self.viewController = viewController
            }
          }
          continuation.onTermination = { _ in
            Task {
              await Self.viewController?.dismiss()
              Self.viewController = nil
            }
          }
        }
        .first(where: { true })
      },
      listener: {
        AsyncStream { continuation in
          class Listener: NSObject, GKLocalPlayerListener {
            let continuation: AsyncStream<ListenerEvent>.Continuation

            init(continuation: AsyncStream<ListenerEvent>.Continuation) {
              self.continuation = continuation
            }

            func player(
              _ player: GKPlayer, didComplete challenge: GKChallenge,
              issuedByFriend friendPlayer: GKPlayer
            ) {
              self.continuation.yield(
                .challenge(.didComplete(challenge, issuedByFriend: friendPlayer)))
            }
            func player(_ player: GKPlayer, didReceive challenge: GKChallenge) {
              self.continuation.yield(.challenge(.didReceive(challenge)))
            }
            func player(
              _ player: GKPlayer, issuedChallengeWasCompleted challenge: GKChallenge,
              byFriend friendPlayer: GKPlayer
            ) {
              self.continuation.yield(
                .challenge(.issuedChallengeWasCompleted(challenge, byFriend: friendPlayer)))
            }
            func player(_ player: GKPlayer, wantsToPlay challenge: GKChallenge) {
              self.continuation.yield(.challenge(.wantsToPlay(challenge)))
            }
            func player(_ player: GKPlayer, didAccept invite: GKInvite) {
              self.continuation.yield(.invite(.didAccept(invite)))
            }
            func player(
              _ player: GKPlayer, didRequestMatchWithRecipients recipientPlayers: [GKPlayer]
            ) {
              self.continuation.yield(.invite(.didRequestMatchWithRecipients(recipientPlayers)))
            }
            func player(_ player: GKPlayer, didModifySavedGame savedGame: GKSavedGame) {
              self.continuation.yield(.savedGame(.didModifySavedGame(savedGame)))
            }
            func player(_ player: GKPlayer, hasConflictingSavedGames savedGames: [GKSavedGame]) {
              self.continuation.yield(.savedGame(.hasConflictingSavedGames(savedGames)))
            }
            func player(
              _ player: GKPlayer, didRequestMatchWithOtherPlayers playersToInvite: [GKPlayer]
            ) {
              self.continuation.yield(.turnBased(.didRequestMatchWithOtherPlayers(playersToInvite)))
            }
            func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {
              self.continuation.yield(.turnBased(.matchEnded(.init(rawValue: match))))
            }
            func player(
              _ player: GKPlayer, receivedExchangeCancellation exchange: GKTurnBasedExchange,
              for match: GKTurnBasedMatch
            ) {
              self.continuation.yield(
                .turnBased(.receivedExchangeCancellation(exchange, match: .init(rawValue: match))))
            }
            func player(
              _ player: GKPlayer, receivedExchangeReplies replies: [GKTurnBasedExchangeReply],
              forCompletedExchange exchange: GKTurnBasedExchange, for match: GKTurnBasedMatch
            ) {
              self.continuation.yield(
                .turnBased(.receivedExchangeReplies(replies, match: .init(rawValue: match))))
            }
            func player(
              _ player: GKPlayer, receivedExchangeRequest exchange: GKTurnBasedExchange,
              for match: GKTurnBasedMatch
            ) {
              self.continuation.yield(
                .turnBased(.receivedExchangeRequest(exchange, match: .init(rawValue: match))))
            }
            func player(
              _ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch,
              didBecomeActive: Bool
            ) {
              self.continuation.yield(
                .turnBased(
                  .receivedTurnEventForMatch(
                    .init(rawValue: match), didBecomeActive: didBecomeActive)))
            }
            func player(_ player: GKPlayer, wantsToQuitMatch match: GKTurnBasedMatch) {
              self.continuation.yield(.turnBased(.wantsToQuitMatch(.init(rawValue: match))))
            }
          }

          let id = UUID()
          let listener = Listener(continuation: continuation)
          Self.listeners[id] = listener
          localPlayer.register(listener)

          continuation.onTermination = { _ in
            localPlayer.unregisterListener(Self.listeners[id]!)
            Self.listeners[id] = nil
          }
        }
      },
      localPlayer: { .init(rawValue: localPlayer) },
      localPlayerAsync: { .init(rawValue: localPlayer) },
      presentAuthenticationViewController: .run { _ in
        Self.viewController?.present()
        return AnyCancellable {
          Self.viewController?.dismiss()
          Self.viewController = nil
        }
      },
      presentAuthenticationViewControllerAsync: {
        await Self.viewController?.present()
        await AsyncStream<Void> { continuation in
          continuation.onTermination = { _ in
            Task {
              await Self.viewController?.dismiss()
              Self.viewController = nil
            }
          }
        }
        .first(where: { true })
      }
    )
  }

  private static var listeners: [UUID: GKLocalPlayerListener] = [:]
  private static var viewController: UIViewController?
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
          match.message = request.message
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
    endMatchInTurnAsync: { request in
      let match = try await GKTurnBasedMatch.load(withID: request.matchId.rawValue)
      match.message = request.message
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
      try await match.endMatchInTurn(withMatch: request.matchData)
    },
    endTurn: { request in
      .future { callback in
        GKTurnBasedMatch.load(withID: request.matchId.rawValue) { match, error in
          guard let match = match else {
            callback(.failure(error ?? invalidStateError))
            return
          }
          match.message = request.message
          match.endTurn(
            withNextParticipants: match.participants
              .filter { $0.player?.gamePlayerID != match.currentParticipant?.player?.gamePlayerID },
            turnTimeout: GKTurnTimeoutDefault,
            match: request.matchData
          ) { error in callback(error.map(Result.failure) ?? .success(())) }
        }
      }
    },
    endTurnAsync: { request in
      let match = try await GKTurnBasedMatch.load(withID: request.matchId.rawValue)
      match.message = request.message
      try await match.endTurn(
        withNextParticipants: match.participants
          .filter { $0.player?.gamePlayerID != match.currentParticipant?.player?.gamePlayerID },
        turnTimeout: GKTurnTimeoutDefault,
        match: request.matchData
      )
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
    loadAsync: { matchId in
      let match = try await GKTurnBasedMatch.load(withID: matchId.rawValue)
      return try await TurnBasedMatch(rawValue: GKTurnBasedMatch.load(withID: matchId.rawValue))
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
    loadMatchesAsync: {
      try await GKTurnBasedMatch.loadMatches().map(TurnBasedMatch.init(rawValue:))
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
    participantQuitInTurnAsync: { matchId, matchData in
      let match = try await GKTurnBasedMatch.load(withID: matchId.rawValue)
      try await match.participantQuitInTurn(
        with: .quit,
        nextParticipants: match.participants
          .filter { $0.player?.gamePlayerID != match.currentParticipant?.player?.gamePlayerID },
        turnTimeout: 0,
        match: matchData
      )
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
    participantQuitOutOfTurnAsync: { matchId in
      let match = try await GKTurnBasedMatch.load(withID: matchId.rawValue)
      try await match.participantQuitOutOfTurn(with: .quit)
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
    rematchAsync: { matchId in
      let match = try await GKTurnBasedMatch.load(withID: matchId.rawValue)
      return try await TurnBasedMatch(rawValue: match.rematch())
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
    removeAsync: { match in
      guard let turnBasedMatch = match.rawValue
      else {
        struct RawValueWasNil: Error {}
        throw RawValueWasNil()
      }
      try await turnBasedMatch.remove()
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
    saveCurrentTurnAsync: { matchId, matchData in
      let match = try await GKTurnBasedMatch.load(withID: matchId.rawValue)
      try await match.saveCurrentTurn(withMatch: matchData)
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
            localizableMessageKey: request.key,
            arguments: request.arguments
          ) { error in callback(error.map(Result.failure) ?? .success(())) }
        }
      }
    },
    sendReminderAsync: { request in
      let match = try await GKTurnBasedMatch.load(withID: request.matchId.rawValue)
      try await match.sendReminder(
        to: request.participantsAtIndices.map { match.participants[$0] },
        localizableMessageKey: request.key,
        arguments: request.arguments
      )
    }
  )
}

@available(iOSApplicationExtension, unavailable)
extension TurnBasedMatchmakerViewControllerClient {
  public static let live = Self(
    present: { showExistingMatches in
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
        matchRequest.inviteMessage = "Let’s play isowords!"  // TODO: Pass in/localize
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
    presentAsync: { showExistingMatches in

    },
    dismiss: .fireAndForget {
      guard let viewController = Self.viewController else { return }
      viewController.dismiss()
      Self.viewController = nil
    },
    dismissAsync: {

    }
  )

  private static var viewController: GKTurnBasedMatchmakerViewController?
}

private let invalidStateError = NSError(domain: "co.pointfree", code: -1)
