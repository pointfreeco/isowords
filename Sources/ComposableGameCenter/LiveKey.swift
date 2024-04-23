#if os(iOS)
  import Dependencies
  import GameKit

  @available(iOSApplicationExtension, unavailable)
  extension GameCenterClient: DependencyKey {
    public static let liveValue = {
      Self(
        gameCenterViewController: .live,
        localPlayer: .live,
        reportAchievements: { try await GKAchievement.report($0) },
        showNotificationBanner: {
          if #available(iOS 16.1, *) {
            var content = UNMutableNotificationContent()
            content.title = $0.title ?? content.title
            content.body = $0.message ?? content.body
            let request = UNNotificationRequest(
              identifier: UUID().uuidString,
              content: content,
              trigger: nil
            )
            try? await UNUserNotificationCenter.current().add(request)
          } else {
            await GKNotificationBanner.show(withTitle: $0.title, message: $0.message)
          }
        },
        turnBasedMatch: .live,
        turnBasedMatchmakerViewController: .live
      )
    }()
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
        present: { await presenter.present() },
        dismiss: { await presenter.dismiss() }
      )
    }
  }

  @available(iOSApplicationExtension, unavailable)
  extension LocalPlayerClient {
    public static var live: Self {
      var localPlayer: GKLocalPlayer { .local }

      return Self(
        // TODO: Used to use `shareReplay(1)` here. Bring back using some local `ActorIsolated`?
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
                self.continuation.yield(
                  .turnBased(.didRequestMatchWithOtherPlayers(playersToInvite)))
              }
              func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {
                self.continuation.yield(.turnBased(.matchEnded(.init(rawValue: match))))
              }
              func player(
                _ player: GKPlayer, receivedExchangeCancellation exchange: GKTurnBasedExchange,
                for match: GKTurnBasedMatch
              ) {
                self.continuation.yield(
                  .turnBased(.receivedExchangeCancellation(exchange, match: .init(rawValue: match)))
                )
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
        presentAuthenticationViewController: {
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
        let match = try await GKTurnBasedMatch.load(withID: matchId.rawValue)
        return try await TurnBasedMatch(rawValue: GKTurnBasedMatch.load(withID: matchId.rawValue))
      },
      loadMatches: { try await GKTurnBasedMatch.loadMatches().map(TurnBasedMatch.init) },
      participantQuitInTurn: { matchId, matchData in
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
        let match = try await GKTurnBasedMatch.load(withID: matchId.rawValue)
        try await match.participantQuitOutOfTurn(with: .quit)
      },
      rematch: { matchId in
        let match = try await GKTurnBasedMatch.load(withID: matchId.rawValue)
        return try await TurnBasedMatch(rawValue: match.rematch())
      },
      remove: { match in
        guard let turnBasedMatch = match.rawValue
        else {
          struct RawValueWasNil: Error {}
          throw RawValueWasNil()
        }
        try await turnBasedMatch.remove()
      },
      saveCurrentTurn: { matchId, matchData in
        let match = try await GKTurnBasedMatch.load(withID: matchId.rawValue)
        try await match.saveCurrentTurn(withMatch: matchData)
      },
      sendReminder: { request in
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
    public static var live: Self {
      actor Presenter {
        var viewController: GKTurnBasedMatchmakerViewController?

        func present(showExistingMatches: Bool) async throws {
          final class Delegate: NSObject, GKTurnBasedMatchmakerViewControllerDelegate {
            let continuation: AsyncThrowingStream<Void, Error>.Continuation

            init(continuation: AsyncThrowingStream<Void, Error>.Continuation) {
              self.continuation = continuation
            }

            func turnBasedMatchmakerViewControllerWasCancelled(
              _ viewController: GKTurnBasedMatchmakerViewController
            ) {
              self.continuation.finish(throwing: CancellationError())
            }

            func turnBasedMatchmakerViewController(
              _ viewController: GKTurnBasedMatchmakerViewController, didFailWithError error: Error
            ) {
              self.continuation.finish(throwing: error)
            }
          }

          await self.dismiss()

          let matchRequest = GKMatchRequest()
          matchRequest.inviteMessage = "Let's play isowords!"
          matchRequest.maxPlayers = 2
          matchRequest.minPlayers = 2

          let viewController: GKTurnBasedMatchmakerViewController = await MainActor.run {
            let viewController = GKTurnBasedMatchmakerViewController(matchRequest: matchRequest)
            viewController.showExistingMatches = showExistingMatches
            return viewController
          }
          self.viewController = viewController

          _ = try await AsyncThrowingStream<Void, Error> { continuation in
            Task {
              await MainActor.run {
                let delegate = Delegate(continuation: continuation)
                continuation.onTermination = { _ in
                  _ = delegate
                  Task { await self.dismiss() }
                }
                viewController.turnBasedMatchmakerDelegate = delegate
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
        present: { try await presenter.present(showExistingMatches: $0) },
        dismiss: { await presenter.dismiss() }
      )
    }
  }
#endif
