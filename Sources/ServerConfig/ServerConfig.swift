import Foundation

public struct ServerConfig: Codable, Equatable, Hashable {
  public var appId: String
  public var newestBuild: Int
  public var forceUpgradeVersion: Int
  public var productIdentifiers: ProductIdentifiers
  public var upgradeInterstitial: UpgradeInterstitial

  public init(
    appId: String = "1528246952",
    forceUpgradeVersion: Int = 0,
    newestBuild: Int = (Changelog.current.changes.map(\.build).max() ?? 0),
    productIdentifiers: ProductIdentifiers = .default,
    upgradeInterstitial: UpgradeInterstitial = .default
  ) {
    self.appId = appId
    self.forceUpgradeVersion = forceUpgradeVersion
    self.newestBuild = newestBuild
    self.productIdentifiers = productIdentifiers
    self.upgradeInterstitial = upgradeInterstitial
  }

  public struct ProductIdentifiers: Codable, Equatable, Hashable {
    public var fullGame: String = "co.pointfree.isowords_testing.full_game"

    public static let `default` = Self()
  }

  public struct UpgradeInterstitial: Codable, Equatable, Hashable {
    public var dailyChallengeTriggerEvery = 1
    public var duration = 10
    public var multiplayerGameTriggerEvery = 4
    public var nagBannerAfterInstallDuration = 60 * 60 * 24 * 2
    public var playedDailyChallengeGamesTriggerCount = 2
    public var playedMultiplayerGamesTriggerCount = 1
    public var playedSoloGamesTriggerCount = 6
    public var soloGameTriggerEvery = 3

    public static let `default` = Self()
  }

  public var appStoreUrl: URL {
    URL(string: "https://apps.apple.com/us/app/isowords/id\(self.appId)")!
  }

  public var appStoreReviewUrl: URL {
    URL(
      string: "https://itunes.apple.com/us/app/apple-store/id\(self.appId)?mt=8&action=write-review"
    )!
  }
}

extension ServerConfig.UpgradeInterstitial {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    let defaults = Self()
    self.duration =
      try container.decodeIfPresent(Int.self, forKey: .duration)
      ?? defaults.duration
    self.playedDailyChallengeGamesTriggerCount =
      try container.decodeIfPresent(Int.self, forKey: .playedDailyChallengeGamesTriggerCount)
      ?? defaults.playedDailyChallengeGamesTriggerCount
    self.playedMultiplayerGamesTriggerCount =
      try container.decodeIfPresent(Int.self, forKey: .playedMultiplayerGamesTriggerCount)
      ?? defaults.playedMultiplayerGamesTriggerCount
    self.playedSoloGamesTriggerCount =
      try container.decodeIfPresent(Int.self, forKey: .playedSoloGamesTriggerCount)
      ?? defaults.playedSoloGamesTriggerCount
    self.dailyChallengeTriggerEvery =
      try container.decodeIfPresent(Int.self, forKey: .dailyChallengeTriggerEvery)
      ?? defaults.dailyChallengeTriggerEvery
    self.multiplayerGameTriggerEvery =
      try container.decodeIfPresent(Int.self, forKey: .multiplayerGameTriggerEvery)
      ?? defaults.multiplayerGameTriggerEvery
    self.soloGameTriggerEvery =
      try container.decodeIfPresent(Int.self, forKey: .soloGameTriggerEvery)
      ?? defaults.soloGameTriggerEvery
    self.nagBannerAfterInstallDuration =
      try container.decodeIfPresent(Int.self, forKey: .nagBannerAfterInstallDuration)
      ?? defaults.nagBannerAfterInstallDuration
  }
}
