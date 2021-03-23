import Either
import XCTestDynamicOverlay

#if DEBUG
  extension DatabaseClient {
    public static let failing = Self(
      completeDailyChallenge: { _, _ in
        .failing("\(Self.self).completeDailyChallenge is unimplemented")
      },
      createTodaysDailyChallenge: { _ in
        .failing("\(Self.self).createTodaysDailyChallenge is unimplemented")
      },
      fetchActiveDailyChallengeArns: {
        .failing("\(Self.self).fetchActiveDailyChallengeArns is unimplemented")
      },
      fetchAppleReceipt: { _ in .failing("\(Self.self).fetchAppleReceipt is unimplemented") },
      fetchDailyChallengeById: { _ in
        .failing("\(Self.self).fetchDailyChallengeById is unimplemented")
      },
      fetchDailyChallengeHistory: { _ in
        .failing("\(Self.self).fetchDailyChallengeHistory is unimplemented")
      },
      fetchDailyChallengeReport: { _ in
        .failing("\(Self.self).fetchDailyChallengeReport is unimplemented")
      },
      fetchDailyChallengeResult: { _ in
        .failing("\(Self.self).fetchDailyChallengeResult is unimplemented")
      },
      fetchDailyChallengeResults: { _ in
        .failing("\(Self.self).fetchDailyChallengeResults is unimplemented")
      },
      fetchLeaderboardSummary: { _ in
        .failing("\(Self.self).fetchLeaderboardSummary is unimplemented")
      },
      fetchLeaderboardWeeklyRanks: { _, _ in
        .failing("\(Self.self).fetchLeaderboardWeeklyRanks is unimplemented")
      },
      fetchLeaderboardWeeklyWord: { _, _ in
        .failing("\(Self.self).fetchLeaderboardWeeklyWord is unimplemented")
      },
      fetchPlayerByAccessToken: { _ in
        .failing("\(Self.self).fetchPlayerByAccessToken is unimplemented")
      },
      fetchPlayerByDeviceId: { _ in .failing("\(Self.self).fetchPlayerByDeviceId is unimplemented")
      },
      fetchPlayerByGameCenterLocalPlayerId: { _ in
        .failing("\(Self.self).fetchPlayerByGameCenterLocalPlayerId is unimplemented")
      },
      fetchRankedLeaderboardScores: { _ in
        .failing("\(Self.self).fetchRankedLeaderboardScores is unimplemented")
      },
      fetchSharedGame: { _ in .failing("\(Self.self).fetchSharedGame is unimplemented") },
      fetchTodaysDailyChallenges: { _ in
        .failing("\(Self.self).fetchTodaysDailyChallenges is unimplemented")
      },
      fetchVocabLeaderboard: { _, _, _ in
        .failing("\(Self.self).fetchVocabLeaderboard is unimplemented")
      },
      fetchVocabLeaderboardWord: { _ in
        .failing("\(Self.self).fetchVocabLeaderboardWord is unimplemented")
      },
      insertPlayer: { _ in .failing("\(Self.self).insertPlayer is unimplemented") },
      insertPushToken: { _ in .failing("\(Self.self).insertPushToken is unimplemented") },
      insertSharedGame: { _, _ in .failing("\(Self.self).insertSharedGame is unimplemented") },
      migrate: { .failing("\(Self.self).migrate is unimplemented") },
      shutdown: { .failing("\(Self.self).shutdown is unimplemented") },
      startDailyChallenge: { _, _ in .failing("\(Self.self).startDailyChallenge is unimplemented")
      },
      submitLeaderboardScore: { _ in
        .failing("\(Self.self).submitLeaderboardScore is unimplemented")
      },
      updateAppleReceipt: { _, _ in .failing("\(Self.self).updateAppleReceipt is unimplemented") },
      updatePlayer: { _ in .failing("\(Self.self).updatePlayer is unimplemented") },
      updatePushSetting: { _, _, _ in .failing("\(Self.self).updatePushSetting is unimplemented") }
    )
  }

  extension EitherIO where E == Error {
    static func failing(_ title: String) -> Self {
      .init(
        run: .init {
          XCTFail("\(title): EitherIO is unimplemented")
          return .left(AnError())
        })
    }
  }

  struct AnError: Error {}
#endif
