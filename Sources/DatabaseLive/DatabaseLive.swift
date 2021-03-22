import CasePaths
import DatabaseClient
import Either
import Foundation
import Overture
import PostgresKit
import Prelude
import SharedModels

extension DatabaseClient {
  public static func live(
    pool: EventLoopGroupConnectionPool<PostgresConnectionSource>
  ) -> Self {
    Self(
      completeDailyChallenge: { dailyChallengeId, playerId in
        pool.sqlDatabase.raw(
          """
          UPDATE "dailyChallengePlays"
          SET "completedAt" = NOW()
          WHERE "dailyChallengeId" = \(bind: dailyChallengeId)
          AND "playerId" = \(bind: playerId)
          AND "completedAt" IS NULL
          RETURNING *
          """
        )
        .first(decoding: DailyChallengePlay.self)
        .mapExcept(requireSome("completeDailyChallenge(\(dailyChallengeId), \(playerId))"))
      },
      createTodaysDailyChallenge: { request in
        pool.sqlDatabase.raw(
          """
          INSERT INTO "dailyChallenges"
          ("gameMode", "language", "puzzle")
          VALUES
          (
            \(bind: request.gameMode),
            \(bind: request.language),
            \(bind: request.puzzle)
          )
          ON CONFLICT ("gameMode", "gameNumber", "language") DO UPDATE
          SET language = \(bind: request.language)
          RETURNING
            *,
            DATE_TRUNC('DAY', NOW() + INTERVAL '1 DAY') AS "endsAt"
          """
        )
        .first(decoding: DailyChallenge.self)
        .mapExcept(requireSome("createTodaysDailyChallenge(\(request))"))
      },
      fetchActiveDailyChallengeArns: {
        pool.sqlDatabase.raw(
          """
          SELECT
            "arn",
            DATE_TRUNC('DAY', NOW() + INTERVAL '1 DAY') AS "endsAt"
          FROM "dailyChallengePlays"
          JOIN "dailyChallenges" ON "dailyChallenges"."id" = "dailyChallengePlays"."dailyChallengeId"
          JOIN "pushTokens" ON "pushTokens"."playerId" = "dailyChallengePlays"."playerId"
          LEFT JOIN "players" ON "players"."id" = "pushTokens"."playerId"
          WHERE "arn" IS NOT NULL
          AND "completedAt" IS NULL
          AND "gameMode" = 'unlimited'
          AND "gameNumber" = CURRENT_DAILY_CHALLENGE_NUMBER();
          """
        )
        .all(decoding: DailyChallengeArn.self)
      },
      fetchAppleReceipt: { playerId in
        pool.sqlDatabase.raw(
          """
          SELECT *
          FROM "appleReceipts"
          WHERE "playerId" = \(bind: playerId)
          """
        )
        .first(decoding: AppleReceipt.self)
      },
      fetchDailyChallengeById: { id in
        pool.sqlDatabase.raw(
          """
          SELECT
            *,
            DATE_TRUNC('DAY', "createdAt" + INTERVAL '1 DAY') AS "endsAt"
          FROM "dailyChallenges"
          WHERE "id" = \(bind: id)
          """
        )
        .first(decoding: DailyChallenge.self)
        .mapExcept(requireSome("fetchDailyChallengeById(\(id))"))
      },
      fetchDailyChallengeHistory: { request in
        pool.sqlDatabase.raw(
          """
          WITH "past30DaysOfDailyChallenges" AS (
            SELECT
              '\(raw: gameEpoch)'::date + ("gameNumber" || ' DAY')::interval AS "createdAt",
              "dailyChallenges"."id" AS "dailyChallengeId",
              "dailyChallenges"."gameNumber",
              "gameNumber" = CURRENT_DAILY_CHALLENGE_NUMBER() AS "isToday",
              count("playerId") AS "outOf"
            FROM
              "leaderboardScores"
            INNER JOIN "dailyChallenges"
              ON "dailyChallenges"."id" = "leaderboardScores"."dailyChallengeId"
            WHERE
              "dailyChallenges"."gameMode" = \(bind: request.gameMode)
              AND "dailyChallenges"."language" = \(bind: request.language)
              AND "gameNumber" >= CURRENT_DAILY_CHALLENGE_NUMBER() - 30
            GROUP BY
              "dailyChallenges"."id"
            ORDER BY
              "gameNumber" DESC
          ),
          "rankedDailyChallengeScores" AS (
            SELECT
              "past30DaysOfDailyChallenges"."createdAt",
              "gameNumber",
              "isToday",
              "players"."id" AS "playerId",
              "outOf",
              DENSE_RANK() OVER (PARTITION BY "past30DaysOfDailyChallenges"."dailyChallengeId" ORDER BY "score" DESC) AS "rank",
              "score"
            FROM
              "leaderboardScores"
            INNER JOIN "past30DaysOfDailyChallenges"
              ON "past30DaysOfDailyChallenges"."dailyChallengeId" = "leaderboardScores"."dailyChallengeId"
            LEFT OUTER JOIN "players" ON "players"."id" = "leaderboardScores"."playerId"
          )
          SELECT
             "past30DaysOfDailyChallenges"."createdAt",
             "past30DaysOfDailyChallenges"."gameNumber",
             "past30DaysOfDailyChallenges"."isToday",
             "rankedDailyChallengeScores"."rank"
          FROM "past30DaysOfDailyChallenges"
          LEFT OUTER JOIN "rankedDailyChallengeScores"
          ON "past30DaysOfDailyChallenges"."gameNumber" = "rankedDailyChallengeScores"."gameNumber"
          AND "rankedDailyChallengeScores"."playerId" = \(bind: request.playerId)
          """
        )
        .all(decoding: DailyChallengeHistoryResponse.Result.self)
      },
      fetchDailyChallengeReport: { request in
        pool.sqlDatabase.raw(
          """
          WITH "rankedDailyChallengeScores" AS (
            SELECT
              "gameNumber",
              "dailyChallenges"."gameMode",
              "leaderboardScores"."playerId" AS "playerId",
              RANK() OVER (PARTITION BY "dailyChallengeId" ORDER BY "score" DESC) AS "rank",
              "score"
            FROM "leaderboardScores"
            LEFT JOIN "dailyChallenges" ON "dailyChallenges"."id" = "leaderboardScores"."dailyChallengeId"
            WHERE
              "dailyChallenges"."gameMode" = \(bind: request.gameMode)
              AND "dailyChallenges"."language" = \(bind: request.language)
              AND "gameNumber" = CURRENT_DAILY_CHALLENGE_NUMBER() - 1
          ),
          "rankedDailyChallengeScoresCount" AS (
            SELECT max("rank") AS "outOf"
            FROM "rankedDailyChallengeScores"
          )
          SELECT DISTINCT "players"."id",
          "arn",
          \(bind: request.gameMode) AS "gameMode",
          "outOf",
          "rank",
          "score"
          FROM "players"
          LEFT JOIN "rankedDailyChallengeScores" ON "rankedDailyChallengeScores"."playerId" = "players"."id"
          LEFT JOIN "pushTokens" on "pushTokens"."playerId" = "players"."id"
          JOIN "rankedDailyChallengeScoresCount" ON 1=1
          WHERE "arn" IS NOT NULL AND (
            "rank" IS NOT NULL AND ("sendDailyChallengeReminder" OR "sendDailyChallengeSummary")
            OR "rank" IS NULL AND "sendDailyChallengeReminder"
          )
          ORDER BY "rank" ASC;
          """
        )
        .all(decoding: DailyChallengeReportResult.self)
      },
      fetchDailyChallengeResult: { request in
        pool.sqlDatabase.raw(
          """
          WITH "filteredDailyChallengeScores" AS (
            SELECT
              "leaderboardScores"."playerId",
              "score",
              DENSE_RANK() OVER (ORDER BY "score" DESC) AS "rank"
            FROM "leaderboardScores"
            WHERE "leaderboardScores"."dailyChallengeId" = \(bind: request.dailyChallengeId)
          ),
          "filteredDailyChallengeScoresCount" AS (
            SELECT count(DISTINCT "score") AS "outOf"
            FROM "filteredDailyChallengeScores"
          ),
          "playerDailyChallengeResult" AS (
            SELECT *
            FROM "filteredDailyChallengeScores"
            WHERE "playerId" = \(bind: request.playerId)
          ),
          "dailyChallengeStarted" AS (
            SELECT 1
            FROM "dailyChallengePlays"
            WHERE "dailyChallengeId" = \(bind: request.dailyChallengeId)
            AND "playerId" = \(bind: request.playerId)
          )
          SELECT
            "outOf",
            "rank",
            "score",
            "dailyChallengeStarted".* IS NOT NULL as "started"
          FROM "filteredDailyChallengeScoresCount"
          LEFT OUTER JOIN "playerDailyChallengeResult" ON 1=1
          LEFT OUTER JOIN "dailyChallengeStarted" ON 1=1;
          """
        )
        .first(decoding: DailyChallengeResult.self)
        .mapExcept(requireSome("fetchDailyChallengeResult(\(request))"))
      },
      fetchDailyChallengeResults: { request in
        pool.sqlDatabase.raw(
          """
          WITH "rankedChallengeResults" AS (
            SELECT
              "appleReceipts"."id" IS NOT NULL AS "isSupporter",
              "players"."id" = \(bind: request.playerId) AS "isYourScore",
              "displayName" AS "playerDisplayName",
              "players"."id" AS "playerId",
              DENSE_RANK() OVER (ORDER BY "score" DESC) AS "rank",
              "score"
            FROM "leaderboardScores"
            JOIN "dailyChallenges" ON "leaderboardScores"."dailyChallengeId" = "dailyChallenges"."id"
            JOIN "players" ON "leaderboardScores"."playerId" = "players"."id"
            LEFT JOIN "appleReceipts" ON "appleReceipts"."playerId" = "players"."id"
            WHERE "dailyChallenges"."gameNumber" = COALESCE(\(bind: request.gameNumber), CURRENT_DAILY_CHALLENGE_NUMBER())
            AND "dailyChallenges"."gameMode" = \(bind: request.gameMode)
            AND "dailyChallenges"."language" = \(bind: request.language)
          ),
          "rankedChallengeResultsCount" AS (
            SELECT count(DISTINCT "score") AS "outOf"
            FROM "rankedChallengeResults"
          )
          SELECT
            *
          FROM "rankedChallengeResults"
          JOIN "rankedChallengeResultsCount" ON 1=1
          WHERE "rank" <= 100 OR "isYourScore"
          ORDER BY "rank" ASC;
          """
        )
        .all(decoding: FetchDailyChallengeResultsResponse.Result.self)
      },
      fetchLeaderboardSummary: { request in
        let playerScoreFilter: SQLQueryString
        let yourScoreFilter: SQLQueryString
        let isAnonymous: Bool

        switch request.type {
        case let .player(scoreId: leaderboardScoreId, playerId: playerId):
          playerScoreFilter = """
            "playerId" != \(bind: playerId) OR "id" = \(bind: leaderboardScoreId)
            """
          yourScoreFilter = """
            "playerId" = \(bind: playerId)
            """
          isAnonymous = false
        case let .anonymous(score: score):
          playerScoreFilter = "1 = 1"
          yourScoreFilter = """
            "score" > \(bind: score)
            """
          isAnonymous = true
        }

        return pool.sqlDatabase.raw(
          """
          WITH "filteredScores" AS (
            SELECT
              DISTINCT ON ("playerId")
              "playerId",
              "score"
            FROM
              "leaderboardScores"
            WHERE
              "createdAt" BETWEEN NOW() - INTERVAL '\(raw: request.timeScope.postgresInterval)' AND NOW()
                AND "gameMode" = \(bind: request.gameMode)
                AND (\(playerScoreFilter))
            ORDER BY
              "playerId",
              "score" DESC
          ),
          "rankedFilteredScores" AS (
            SELECT
              *,
              DENSE_RANK() OVER (ORDER BY "score" DESC) AS "rank"
            FROM "filteredScores"
            ORDER BY "score" ASC
          ),
          "yourRank" AS (
            SELECT *
            FROM "rankedFilteredScores"
            WHERE \(yourScoreFilter)
          ),
          "filteredScoresCount" AS (
            SELECT
              COUNT(DISTINCT "playerId") AS "outOf"
            FROM
              "filteredScores"
          )
          SELECT
            "outOf" + (CASE WHEN \(bind: isAnonymous) THEN 1 ELSE 0 END) as "outOf",
            COALESCE("rank", 0) + (CASE WHEN \(bind: isAnonymous) THEN 1 ELSE 0 END) AS "rank"
          FROM
            "filteredScoresCount"
          LEFT JOIN "yourRank" ON TRUE
          LIMIT 1
          """
        )
        .first(decoding: LeaderboardScoreResult.Rank.self)
        .mapExcept(requireSome("fetchLeaderboardSummary(\(request))"))
      },
      fetchLeaderboardWeeklyRanks: { language, player in
        pool.sqlDatabase.raw(
          """
          WITH "filteredScores" AS (
            SELECT
              "leaderboardScores"."playerId",
              "leaderboardScores"."gameMode",
              MAX("leaderboardScores"."score") AS "score"
            FROM "leaderboardScores"
            LEFT JOIN "dailyChallenges" ON "leaderboardScores"."dailyChallengeId" = "dailyChallenges"."id"
            WHERE "leaderboardScores"."language" = \(bind: language)
            AND "leaderboardScores"."createdAt" BETWEEN NOW() - INTERVAL '7 DAY' AND NOW()
            AND (
              "leaderboardScores"."dailyChallengeId" IS NULL
              OR "dailyChallenges"."gameNumber" != CURRENT_DAILY_CHALLENGE_NUMBER()
            )
            AND "leaderboardScores"."gameContext" IN ('dailyChallenge', 'solo')
            GROUP BY "playerId", "leaderboardScores"."gameMode"
          ),
          "rankedFilteredScores" AS (
            SELECT
              *,
              RANK() OVER (PARTITION BY "gameMode" ORDER BY "score" DESC) AS "rank"
            FROM "filteredScores"
          ),
          "filteredScoresCount" AS (
            SELECT
              COUNT(DISTINCT "playerId") AS "outOf",
              "gameMode"
            FROM "filteredScores"
            GROUP BY "gameMode"
          )
          SELECT "rankedFilteredScores"."gameMode", "outOf", "rank"
          FROM "rankedFilteredScores"
          INNER JOIN "filteredScoresCount" ON "rankedFilteredScores"."gameMode" = "filteredScoresCount"."gameMode"
          WHERE "playerId" = \(bind: player.id)
          ORDER BY "gameMode"
          """
        )
        .all(decoding: FetchWeekInReviewResponse.Rank.self)
      },
      fetchLeaderboardWeeklyWord: { language, player in
        pool.sqlDatabase.raw(
          """
          SELECT "words"."word" AS "letters", "words"."score"
            FROM "leaderboardScores"
          INNER JOIN "words"
            ON "leaderboardScores"."id" = "words"."leaderboardScoreId"
          LEFT JOIN "dailyChallenges"
            ON "leaderboardScores"."dailyChallengeId" = "dailyChallenges"."id"
          WHERE "leaderboardScores"."language" = \(bind: language)
          AND "playerId" = \(bind: player.id)
          AND "leaderboardScores"."createdAt" BETWEEN NOW() - INTERVAL '7 DAY' AND NOW()
          AND (
            "leaderboardScores"."dailyChallengeId" IS NULL
            OR "dailyChallenges"."gameNumber" != CURRENT_DAILY_CHALLENGE_NUMBER()
          )
          ORDER BY "words"."score" DESC, "words"."createdAt" DESC
          LIMIT 1
          """
        )
        .first(decoding: FetchWeekInReviewResponse.Word.self)
      },
      fetchPlayerByAccessToken: { accessToken in
        pool.sqlDatabase.raw(
          """
          SELECT *
          FROM "players"
          WHERE "accessToken" = \(bind: accessToken)
          """
        )
        .first(decoding: Player.self)
      },
      fetchPlayerByDeviceId: { deviceId in
        pool.sqlDatabase.raw(
          """
          SELECT *
          FROM "players"
          WHERE "deviceId" = \(bind: deviceId)
          """
        )
        .first(decoding: Player.self)
      },
      fetchPlayerByGameCenterLocalPlayerId: { gameCenterLocalPlayerId in
        pool.sqlDatabase.raw(
          """
          SELECT *
          FROM "players"
          WHERE "gameCenterLocalPlayerId" = \(bind: gameCenterLocalPlayerId)
          """
        )
        .first(decoding: Player.self)
      },
      fetchRankedLeaderboardScores: { request in
        pool.sqlDatabase.raw(
          """
          WITH distinctScores AS (
            SELECT
              DISTINCT ON ("leaderboardScores"."playerId")
              "displayName" AS "playerDisplayName",
              "leaderboardScores"."id",
              "appleReceipts"."id" IS NOT NULL AS "isSupporter",
              "players"."id" = \(bind: request.playerId) AS "isYourScore",
              "players"."id" AS "playerId",
              "score"
            FROM
              "leaderboardScores"
            LEFT JOIN "players" ON "leaderboardScores"."playerId" = "players"."id"
            LEFT JOIN "appleReceipts" ON "appleReceipts"."playerId" = "players"."id"
            LEFT JOIN "dailyChallenges" ON "leaderboardScores"."dailyChallengeId" = "dailyChallenges"."id"
          WHERE
            "leaderboardScores"."gameMode" = \(bind: request.gameMode)
            AND "leaderboardScores"."language" = \(bind: request.language)
            AND (
              -- Daily challenges get a little more time for `lastDay` scopes since their scores
              -- aren't released until the challenge is over.
              (
                "leaderboardScores"."gameContext" = 'dailyChallenge'
                AND '\(raw: request.timeScope.rawValue)' = 'lastDay'
                AND DATE_TRUNC('DAY', "leaderboardScores"."createdAt" + INTERVAL '1 DAY') BETWEEN
                  NOW() - INTERVAL '\(raw: request.timeScope.postgresInterval)' AND NOW()
              )
              OR "leaderboardScores"."createdAt" BETWEEN
                NOW() - INTERVAL '\(raw: request.timeScope.postgresInterval)' AND NOW()
            )
            AND (
              "leaderboardScores"."dailyChallengeId" IS NULL
              OR "dailyChallenges"."gameNumber" != CURRENT_DAILY_CHALLENGE_NUMBER()
            )
            AND "leaderboardScores"."gameContext" IN ('dailyChallenge', 'solo')
          ORDER BY
            "leaderboardScores"."playerId",
            "score" DESC
          ),
          "rankedScores" AS (
            SELECT
              *,
              (SELECT COUNT("playerId") FROM distinctScores) AS "outOf",
              DENSE_RANK() OVER (ORDER BY "score" DESC) AS "rank"
            FROM
              distinctScores
          )
          SELECT
            *
          FROM "rankedScores"
          WHERE
            "playerId" = \(bind: request.playerId)
              OR "rank" <= 20
          """
        )
        .all(decoding: FetchLeaderboardResponse.Entry.self)
      },
      fetchSharedGame: { code in
        pool.sqlDatabase.raw(
          """
          SELECT * FROM "sharedGames"
          WHERE "code" = \(bind: code)
          """
        )
        .first(decoding: SharedGame.self)
        .mapExcept(requireSome("fetchSharedGame(\(code))"))
      },
      fetchTodaysDailyChallenges: { language in
        pool.sqlDatabase.raw(
          """
          SELECT
            *,
            DATE_TRUNC('DAY', "createdAt" + INTERVAL '1 DAY') AS "endsAt"
          FROM "dailyChallenges"
          WHERE
            "gameNumber" = CURRENT_DAILY_CHALLENGE_NUMBER()
            AND "language" = \(bind: language)
          """
        )
        .all(decoding: DailyChallenge.self)
      },
      fetchVocabLeaderboard: { language, player, timeScope in
        let orderByClause: SQLQueryString
        switch timeScope {
        case .allTime, .lastDay, .lastWeek:
          orderByClause = #""score" DESC"#
        case .interesting:
          orderByClause = #""score" * "moveIndex" DESC"#
        }
        let minimumScore: Int
        switch timeScope {
        case .allTime:
          minimumScore = 800
        case .lastDay:
          minimumScore = 200
        case .lastWeek:
          minimumScore = 400
        case .interesting:
          minimumScore = 400
        }

        return pool.sqlDatabase.raw(
          """
          WITH "scores" AS (
            SELECT
              DISTINCT ON ("leaderboardScores"."playerId", "words"."word")
              "appleReceipts"."id" IS NOT NULL AS "isSupporter",
              "players"."id" = \(bind: player.id) AS "isYourScore",
              "words"."moveIndex",
              "words"."id" AS "wordId",
              "words"."score",
              "words"."word",
              "players"."displayName" AS "playerDisplayName",
              "players"."id" AS "playerId",
              "words"."createdAt" AS "wordCreatedAt"
            FROM
              "words"
            LEFT JOIN "leaderboardScores" ON "leaderboardScores"."id" = "words"."leaderboardScoreId"
            LEFT JOIN "players" ON "players"."id" = "leaderboardScores"."playerId"
            LEFT JOIN "appleReceipts" ON "appleReceipts"."playerId" = "players"."id"
            LEFT JOIN "dailyChallenges" ON "leaderboardScores"."dailyChallengeId" = "dailyChallenges"."id"
            LEFT OUTER JOIN "hiddenWords" ON "words"."word" = "hiddenWords"."word"
            WHERE
            "words"."score" >= \(bind: minimumScore)
            AND (
              -- Words from daily challenges get a little more time for `lastDay` scopes since
              -- their scores aren't released until the challenge is over.
              (
                "leaderboardScores"."gameContext" = 'dailyChallenge'
                AND '\(raw: timeScope.rawValue)' = 'lastDay'
                AND DATE_TRUNC('DAY', "words"."createdAt" + INTERVAL '1 DAY') BETWEEN
                  NOW() - INTERVAL '\(raw: timeScope.postgresInterval)' AND NOW()
              )
              OR "words"."createdAt" BETWEEN
                NOW() - INTERVAL '\(raw: timeScope.postgresInterval)' AND NOW()
            )
            AND (
              "leaderboardScores"."dailyChallengeId" IS NULL
              OR "dailyChallenges"."gameNumber" != CURRENT_DAILY_CHALLENGE_NUMBER()
            )
            AND (
              "leaderboardScores"."playerId" = \(bind: player.id)
              OR "hiddenWords"."word" IS NULL
            )
          ),
          "rankedScores" AS (
            SELECT
              *,
              RANK() OVER (ORDER BY \(orderByClause)) AS "rank",
              DENSE_RANK() OVER (ORDER BY \(orderByClause)) AS "denseRank"
            FROM "scores"
            ORDER BY
              \(orderByClause), "word" ASC, "wordCreatedAt" ASC
            LIMIT 150
          ),
          "wordCount" AS (
            SELECT COUNT(*) as "outOf"
            FROM "words"
            WHERE "words"."createdAt" BETWEEN
              NOW() - INTERVAL '\(raw: timeScope.postgresInterval)' AND NOW()
          ),
          "top100" AS (
            SELECT
              *
            FROM
              "rankedScores"
            LEFT JOIN "wordCount" ON 1=1
            WHERE "rank" <= 100
          )
          SELECT * FROM "top100";
          """
        )
        .all(decoding: FetchVocabLeaderboardResponse.Entry.self)
      },
      fetchVocabLeaderboardWord: { wordId in
        pool.sqlDatabase.raw(
          """
          SELECT
            "words"."moveIndex" AS "moveIndex",
            "leaderboardScores"."moves" AS "moves",
            "players"."displayName" AS "playerDisplayName",
            "players"."id" AS "playerId",
            "leaderboardScores"."puzzle" AS "puzzle"
          FROM "words"
          LEFT JOIN "leaderboardScores" ON "leaderboardScores"."id" = "words"."leaderboardScoreId"
          LEFT JOIN "players" ON "players"."id" = "leaderboardScores"."playerId"
          WHERE "words"."id" = \(bind: wordId)
          """
        )
        .first(decoding: FetchVocabWordResponse.self)
        .mapExcept(requireSome("fetchVocabLeaderboardWord(\(wordId))"))
      },
      insertPlayer: { request in
        pool.sqlDatabase.raw(
          """
          INSERT INTO "players"
          ("deviceId", "displayName", "gameCenterLocalPlayerId", "timeZone")
          VALUES
          (
            \(bind: request.deviceId),
            \(bind: request.displayName),
            \(bind: request.gameCenterLocalPlayerId),
            \(bind: request.timeZone)
          )
          RETURNING *
          """
        )
        .first(decoding: Player.self)
        .mapExcept(requireSome("insertPlayer(\(request))"))
      },
      insertPushToken: { request in
        pool.sqlDatabase.raw(
          """
          INSERT INTO "pushTokens"
          ("arn", "authorizationStatus", "build", "playerId", "token")
          VALUES
          (
            \(bind: request.arn),
            \(bind: request.authorizationStatus),
            \(bind: request.build),
            \(bind: request.player.id),
            \(bind: request.token)
          )
          ON CONFLICT ("token")
          DO UPDATE SET
            "build" = \(bind: request.build),
            "authorizationStatus" = \(bind: request.authorizationStatus),
            "updatedAt" = NOW()
          """
        )
        .run()
      },
      insertSharedGame: { completedGame, player in
        pool.sqlDatabase.raw(
          """
          INSERT INTO "sharedGames"
          ("gameMode", "language", "moves", "playerId", "puzzle")
          VALUES
          (
            \(bind: completedGame.gameMode),
            \(bind: completedGame.language),
            \(bind: completedGame.moves),
            \(bind: player.id),
            \(bind: completedGame.cubes)
          )
          RETURNING *
          """
        )
        .first(decoding: SharedGame.self)
        .mapExcept(requireSome("insertSharedGame(\(completedGame), \(player))"))
      },
      migrate: { () -> EitherIO<Error, Void> in
        let database = pool.database(logger: Logger(label: "Postgres"))
        return sequence([
          database.run(
            #"CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "public""#
          ),
          database.run(
            #"CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "public""#
          ),
          database.run(
            #"CREATE EXTENSION IF NOT EXISTS "citext" WITH SCHEMA "public""#
          ),
          database.run(
            """
            CREATE OR REPLACE FUNCTION CURRENT_DAILY_CHALLENGE_NUMBER() RETURNS integer AS $$
            BEGIN
            RETURN (NOW()::date - '\(raw: gameEpoch)'::date);
            END; $$
            LANGUAGE PLPGSQL;
            """
          ),
          database.run(
            """
            CREATE TABLE IF NOT EXISTS "players" (
              "id" uuid DEFAULT uuid_generate_v1mc() PRIMARY KEY NOT NULL,
              "accessToken" uuid DEFAULT uuid_generate_v1mc() NOT NULL,
              "deviceId" uuid NOT NULL UNIQUE,
              "displayName" character varying,
              "gameCenterLocalPlayerId" character varying UNIQUE,
              "createdAt" timestamp without time zone DEFAULT NOW() NOT NULL
            )
            """
          ),
          database.run(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS "index_players_on_deviceId"
            ON "players" ("deviceId")
            """
          ),
          database.run(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS "index_players_on_gameCenterLocalPlayerId"
            ON "players" ("gameCenterLocalPlayerId")
            """
          ),
          database.run(
            """
            CREATE TABLE IF NOT EXISTS "dailyChallenges" (
              "id" uuid DEFAULT uuid_generate_v1mc() PRIMARY KEY NOT NULL,
              "gameMode" character varying NOT NULL,
              "gameNumber" integer DEFAULT CURRENT_DAILY_CHALLENGE_NUMBER() NOT NULL,
              "language" character varying NOT NULL,
              "puzzle" jsonb NOT NULL,
              "createdAt" timestamp without time zone DEFAULT NOW() NOT NULL
            )
            """
          ),
          database.run(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS "index_dailyChallenges_on_gameMode_gameNumber_language"
            ON "dailyChallenges" ("gameMode", "gameNumber", "language")
            """
          ),
          database.run(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS "index_dailyChallenges_on_puzzle"
            ON "dailyChallenges" ("puzzle")
            """
          ),
          database.run(
            """
            CREATE TABLE IF NOT EXISTS "leaderboardScores" (
              "id" uuid DEFAULT uuid_generate_v1mc() PRIMARY KEY NOT NULL,
              "gameMode" character varying NOT NULL,
              "language" character varying NOT NULL,
              "moves" jsonb NOT NULL,
              "playerId" uuid REFERENCES "players" ("id") NOT NULL,
              "puzzle" jsonb NOT NULL,
              "score" integer NOT NULL,
              "createdAt" timestamp without time zone DEFAULT NOW() NOT NULL
            )
            """
          ),
          database.run(
            """
            CREATE INDEX IF NOT EXISTS "index_leaderboardScores_on_gameMode_language"
            ON "leaderboardScores" ("gameMode", "language")
            """
          ),
          database.run(
            """
            CREATE INDEX IF NOT EXISTS "index_leaderboardScores_on_score"
            ON "leaderboardScores" ("score")
            """
          ),
          database.run(
            """
            CREATE INDEX IF NOT EXISTS "index_leaderboardScores_on_playerId"
            ON "leaderboardScores" ("playerId")
            """
          ),
          database.run(
            """
            CREATE TABLE IF NOT EXISTS "words" (
              "id" uuid DEFAULT uuid_generate_v1mc() PRIMARY KEY NOT NULL,
              "leaderboardScoreId" uuid REFERENCES "leaderboardScores" ("id") NOT NULL,
              "moveIndex" integer NOT NULL,
              "score" integer NOT NULL,
              "word" character varying NOT NULL,
              "createdAt" timestamp without time zone DEFAULT NOW() NOT NULL
            )
            """
          ),
          database.run(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS "index_words_on_leaderboardScoreId_word"
            ON "words" ("leaderboardScoreId", "word")
            """
          ),
          database.run(
            """
            CREATE INDEX IF NOT EXISTS "index_words_on_score"
            ON "words" ("score")
            """
          ),
          database.run(
            """
            CREATE TABLE IF NOT EXISTS "appleReceipts" (
              "id" uuid DEFAULT uuid_generate_v1mc() PRIMARY KEY NOT NULL,
              "playerId" uuid REFERENCES "players" ("id") NOT NULL,
              "receipt" jsonb NOT NULL,
              "createdAt" timestamp without time zone DEFAULT NOW() NOT NULL
            )
            """
          ),
          database.run(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS "index_appleReceipts_on_playerId"
            ON "appleReceipts" ("playerId")
            """
          ),
          database.run(
            """
            CREATE OR REPLACE FUNCTION gen_shortid(table_name text, column_name text)
            RETURNS text AS $$
            DECLARE
              id text;
              results text;
              times integer := 0;
            BEGIN
              LOOP
                id := encode(gen_random_bytes(6), 'base64');
                id := replace(id, '/', 'p');
                id := replace(id, '+', 'f');
                EXECUTE 'SELECT '
                  || quote_ident(column_name)
                  || ' FROM '
                  || quote_ident(table_name)
                  || ' WHERE '
                  || quote_ident(column_name)
                  || ' = '
                  || quote_literal(id) INTO results;
                IF results IS NULL THEN
                  EXIT;
                END IF;
                times := times + 1;
                IF times > 100 THEN
                  id := NULL;
                  EXIT;
                END IF;
              END LOOP;
              RETURN id;
            END;
            $$ LANGUAGE 'plpgsql';
            """
          ),
          database.run(
            """
            CREATE TABLE IF NOT EXISTS "sharedGames" (
              "id" uuid DEFAULT uuid_generate_v1mc() PRIMARY KEY NOT NULL,
              "code" character varying DEFAULT gen_shortid('sharedGames', 'code') NOT NULL,
              "gameMode" character varying NOT NULL,
              "language" character varying NOT NULL,
              "moves" jsonb NOT NULL,
              "playerId" uuid REFERENCES "players" ("id") NOT NULL,
              "puzzle" jsonb NOT NULL,
              "createdAt" timestamp without time zone DEFAULT NOW() NOT NULL
            )
            """
          ),
          database.run(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS "index_sharedGames_code"
            ON "sharedGames" ("code")
            """
          ),
          database.run(
            """
            ALTER TABLE "leaderboardScores"
            ADD COLUMN IF NOT EXISTS "dailyChallengeId" uuid REFERENCES "dailyChallenges" ("id"),
            ADD COLUMN IF NOT EXISTS "gameContext" character varying DEFAULT 'solo' NOT NULL
            """
          ),
          database.run(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS "index_leaderboardScores_on_dailyChallengeId_playerId"
            ON "leaderboardScores" ("dailyChallengeId", "playerId")
            """
          ),
          database.run(
            """
            CREATE TABLE IF NOT EXISTS "pushTokens" (
              "id" uuid DEFAULT uuid_generate_v1mc() PRIMARY KEY NOT NULL,
              "arn" character varying NOT NULL,
              "playerId" uuid REFERENCES "players" ("id") NOT NULL,
              "token" character varying NOT NULL,
              "createdAt" timestamp without time zone DEFAULT NOW() NOT NULL
            )
            """
          ),
          database.run(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS "index_pushTokens_on_token"
            ON "pushTokens" ("token")
            """
          ),
          database.run(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS "index_pushTokens_on_arn"
            ON "pushTokens" ("arn")
            """
          ),
          database.run(
            """
            CREATE INDEX IF NOT EXISTS "index_pushTokens_on_playerId"
            ON "pushTokens" ("playerId")
            """
          ),
          database.run(
            """
            CREATE TABLE IF NOT EXISTS "dailyChallengePlays" (
              "id" uuid DEFAULT uuid_generate_v1mc() PRIMARY KEY NOT NULL,
              "completedAt" timestamp without time zone,
              "dailyChallengeId" uuid REFERENCES "dailyChallenges" ("id") NOT NULL,
              "playerId" uuid REFERENCES "players" ("id") NOT NULL,
              "createdAt" timestamp without time zone DEFAULT NOW() NOT NULL
            )
            """
          ),
          database.run(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS "index_dailyChallengePlays_on_dailyChallengeId_playerId"
            ON "dailyChallengePlays" ("dailyChallengeId", "playerId")
            """
          ),
          database.run(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS "index_leaderboardScores_on_puzzle_playerId"
            ON "leaderboardScores" ("puzzle", "playerId")
            """
          ),
          database.run(
            """
            ALTER TABLE "players"
            ADD COLUMN IF NOT EXISTS "timeZone" text DEFAULT 'America/New_York' NOT NULL
            """
          ),
          database.run(
            """
            ALTER TABLE "players" ALTER COLUMN "timeZone" DROP DEFAULT
            """
          ),
          database.run(
            """
            ALTER TABLE "pushTokens"
            ADD COLUMN IF NOT EXISTS "build" int DEFAULT 0 NOT NULL
            """
          ),
          database.run(
            """
            ALTER TABLE "pushTokens" ALTER COLUMN "build" DROP DEFAULT
            """
          ),
          database.run(
            """
            ALTER TABLE "pushTokens"
            ADD COLUMN IF NOT EXISTS "updatedAt" timestamp without time zone DEFAULT NOW() NOT NULL
            """
          ),
          database.run(
            """
            ALTER TABLE "players"
            ADD COLUMN IF NOT EXISTS "sendDailyChallengeReminder" boolean DEFAULT TRUE NOT NULL,
            ADD COLUMN IF NOT EXISTS "sendDailyChallengeSummary" boolean DEFAULT TRUE NOT NULL
            """
          ),
          database.run(
            """
            CREATE OR REPLACE FUNCTION PUSH_AUTHORIZATION_STATUS(rawValue int)
            RETURNS text AS $$
            BEGIN
              CASE rawValue
              WHEN 2 THEN
                RETURN 'authorized';
              WHEN 1 THEN
                RETURN 'denied';
              WHEN 4 THEN
                RETURN 'ephemeral';
              WHEN 0 THEN
                RETURN 'notDetermined';
              WHEN 3 THEN
                RETURN 'provisional';
              ELSE
                RETURN '' || rawValue;
              END CASE;
            END;
            $$ LANGUAGE 'plpgsql';
            """
          ),
          database.run(
            """
            ALTER TABLE "pushTokens"
            ADD COLUMN IF NOT EXISTS "authorizationStatus" int DEFAULT 3 NOT NULL
            """
          ),
          database.run(
            """
            CREATE TABLE IF NOT EXISTS "hiddenWords" (
              "word" text NOT NULL UNIQUE
            )
            """
          ),
        ])
        .map(const(()))
      },
      shutdown: {
        .init(
          run: .init {
            do {
              try pool.syncShutdownGracefully()
              return .right(())
            } catch {
              return .left(error)
            }
          })
      },
      startDailyChallenge: { dailyChallengeId, playerId in
        pool.sqlDatabase.raw(
          """
          INSERT INTO "dailyChallengePlays"
          ("dailyChallengeId", "playerId")
          VALUES
          (
            \(bind: dailyChallengeId),
            \(bind: playerId)
          )
          RETURNING *
          """
        )
        .first(decoding: DailyChallengePlay.self)
        .mapExcept(requireSome("startDailyChallenge(\(dailyChallengeId), \(playerId))"))
      },
      submitLeaderboardScore: { request in
        pool.sqlDatabase.raw(
          """
          INSERT INTO "leaderboardScores"
          ("dailyChallengeId", "gameContext", "gameMode", "language", "moves", "playerId", "puzzle", "score")
          VALUES
          (
            \(bind: request.dailyChallengeId),
            \(bind: request.gameContext),
            \(bind: request.gameMode),
            \(bind: request.language),
            \(bind: request.moves),
            \(bind: request.playerId),
            \(bind: request.puzzle),
            \(bind: request.score)
          )
          ON CONFLICT ("puzzle", "playerId")
          DO UPDATE SET "language" = \(bind: request.language)
          RETURNING *
          """
        )
        .first(decoding: LeaderboardScore.self)
        .mapExcept(requireSome("submitLeaderboardScore(\(request))"))
        .flatMap { (leaderboardScore: LeaderboardScore) in
          sequence(
            request.words
              .map { word in
                pool.sqlDatabase.raw(
                  """
                  INSERT INTO "words"
                  ("leaderboardScoreId", "moveIndex", "score", "word")
                  VALUES
                  (
                    \(bind: leaderboardScore.id),
                    \(bind: word.moveIndex),
                    \(bind: word.score),
                    \(bind: word.word)
                  )
                  ON CONFLICT ("leaderboardScoreId", "word")
                  DO UPDATE SET "score" = \(bind: word.score)
                  """
                )
                .run()
              }
          )
          .map(const(leaderboardScore))
        }
      },
      updateAppleReceipt: { playerId, receipt in
        pool.sqlDatabase.raw(
          """
          INSERT INTO "appleReceipts"
          ("playerId", "receipt")
          VALUES
          (\(bind: playerId), \(bind: receipt))
          ON CONFLICT ("playerId") DO UPDATE
          SET receipt = \(bind: receipt)
          """
        )
        .run()
      },
      updatePlayer: { request in
        pool.sqlDatabase.raw(
          """
          UPDATE "players"
          SET "displayName" = COALESCE(\(bind: request.displayName), "displayName"),
              "gameCenterLocalPlayerId" = COALESCE(\(bind: request.gameCenterLocalPlayerId), "gameCenterLocalPlayerId"),
              "timeZone" = \(bind: request.timeZone)
          WHERE "id" = \(bind: request.playerId)
          RETURNING *
          """
        )
        .first(decoding: Player.self)
        .mapExcept(requireSome("updatePlayer(\(request))"))
      },
      updatePushSetting: { playerId, pushNotificationType, sendNotifications in
        return pool.sqlDatabase.raw(
          """
          UPDATE "players"
          SET "\(raw: pushNotificationType.postgresColumn)" = \(bind: sendNotifications)
          WHERE "id" = \(bind: playerId)
          """
        )
        .run()
      }
    )
  }

  #if DEBUG
    public func resetForTesting(pool: EventLoopGroupConnectionPool<PostgresConnectionSource>) throws
    {
      let database = pool.database(logger: Logger(label: "Postgres"))
      try database.run("DROP SCHEMA IF EXISTS public CASCADE").run.perform().unwrap()
      try database.run("CREATE SCHEMA public").run.perform().unwrap()
      try database.run("GRANT ALL ON SCHEMA public TO isowords").run.perform().unwrap()
      try database.run("GRANT ALL ON SCHEMA public TO public").run.perform().unwrap()
      try self.migrate().run.perform().unwrap()
      try database.run("CREATE SEQUENCE test_uuids").run.perform().unwrap()
      try database.run("CREATE SEQUENCE test_shortids").run.perform().unwrap()
      try database.run(
        """
        CREATE OR REPLACE FUNCTION uuid_generate_v1mc() RETURNS uuid AS $$
        BEGIN
        RETURN ('00000000-0000-0000-0000-'||LPAD(nextval('test_uuids')::text, 12, '0'))::uuid;
        END; $$
        LANGUAGE PLPGSQL;
        """
      )
      .run.perform().unwrap()
    }
  #endif
}

func requireSome<A>(
  _ message: String
) -> (Either<Error, A?>) -> Either<Error, A> {
  { e in
    switch e {
    case let .left(e):
      return .left(e)
    case let .right(a):
      return a.map(Either.right) ?? .left(RequireSomeError(message: message))
    }
  }
}

struct RequireSomeError: Error {
  let message: String
}

private let gameEpoch = "2020-01-01"

extension PushNotificationContent.CodingKeys {
  fileprivate var postgresColumn: String {
    switch self {
    case .dailyChallengeEndsSoon:
      return "sendDailyChallengeReminder"
    case .dailyChallengeReport:
      return "sendDailyChallengeSummary"
    }
  }
}

extension TimeScope {
  var postgresInterval: String {
    switch self {
    case .allTime:
      return "99 YEARS"
    case .interesting:
      return "99 YEARS"
    case .lastDay:
      return "1 DAY"
    case .lastWeek:
      return "1 WEEK"
    }
  }
}
