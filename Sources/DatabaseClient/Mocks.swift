import Either
import ServerTestHelpers
import XCTestDynamicOverlay

#if DEBUG
  extension DatabaseClient {
    public static let testValue = Self(
      completeDailyChallenge: { _, _ in
        .unimplemented("\(Self.self).completeDailyChallenge")
      },
      createTodaysDailyChallenge: { _ in
        .unimplemented("\(Self.self).createTodaysDailyChallenge")
      },
      fetchActiveDailyChallengeArns: {
        .unimplemented("\(Self.self).fetchActiveDailyChallengeArns")
      },
      fetchAppleReceipt: { _ in .unimplemented("\(Self.self).fetchAppleReceipt") },
      fetchDailyChallengeById: { _ in
        .unimplemented("\(Self.self).fetchDailyChallengeById")
      },
      fetchDailyChallengeHistory: { _ in
        .unimplemented("\(Self.self).fetchDailyChallengeHistory")
      },
      fetchDailyChallengeReport: { _ in
        .unimplemented("\(Self.self).fetchDailyChallengeReport")
      },
      fetchDailyChallengeResult: { _ in
        .unimplemented("\(Self.self).fetchDailyChallengeResult")
      },
      fetchDailyChallengeResults: { _ in
        .unimplemented("\(Self.self).fetchDailyChallengeResults")
      },
      fetchLeaderboardSummary: { _ in
        .unimplemented("\(Self.self).fetchLeaderboardSummary")
      },
      fetchLeaderboardWeeklyRanks: { _, _ in
        .unimplemented("\(Self.self).fetchLeaderboardWeeklyRanks")
      },
      fetchLeaderboardWeeklyWord: { _, _ in
        .unimplemented("\(Self.self).fetchLeaderboardWeeklyWord")
      },
      fetchPlayerByAccessToken: { _ in
        .unimplemented("\(Self.self).fetchPlayerByAccessToken")
      },
      fetchPlayerByDeviceId: { _ in .unimplemented("\(Self.self).fetchPlayerByDeviceId")
      },
      fetchPlayerByGameCenterLocalPlayerId: { _ in
        .unimplemented("\(Self.self).fetchPlayerByGameCenterLocalPlayerId")
      },
      fetchRankedLeaderboardScores: { _ in
        .unimplemented("\(Self.self).fetchRankedLeaderboardScores")
      },
      fetchSharedGame: { _ in .unimplemented("\(Self.self).fetchSharedGame") },
      fetchTodaysDailyChallenges: { _ in
        .unimplemented("\(Self.self).fetchTodaysDailyChallenges")
      },
      fetchVocabLeaderboard: { _, _, _ in
        .unimplemented("\(Self.self).fetchVocabLeaderboard")
      },
      fetchVocabLeaderboardWord: { _ in
        .unimplemented("\(Self.self).fetchVocabLeaderboardWord")
      },
      insertPlayer: { _ in .unimplemented("\(Self.self).insertPlayer") },
      insertPushToken: { _ in .unimplemented("\(Self.self).insertPushToken") },
      insertSharedGame: { _, _ in .unimplemented("\(Self.self).insertSharedGame") },
      migrate: { .unimplemented("\(Self.self).migrate") },
      shutdown: { .unimplemented("\(Self.self).shutdown") },
      startDailyChallenge: { _, _ in .unimplemented("\(Self.self).startDailyChallenge")
      },
      submitLeaderboardScore: { _ in
        .unimplemented("\(Self.self).submitLeaderboardScore")
      },
      updateAppleReceipt: { _, _ in .unimplemented("\(Self.self).updateAppleReceipt") },
      updatePlayer: { _ in .unimplemented("\(Self.self).updatePlayer") },
      updatePushSetting: { _, _, _ in .unimplemented("\(Self.self).updatePushSetting") }
    )
  }
#endif
