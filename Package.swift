// swift-tools-version:5.3

import Foundation
import PackageDescription

var package = Package(
  name: "isowords",
  platforms: [
    .macOS(.v10_15),
    .iOS(.v14),
  ],
  products: [
    .library(name: "AnyComparable", targets: ["AnyComparable"]),
    .library(name: "Build", targets: ["Build"]),
    .library(name: "DatabaseClient", targets: ["DatabaseClient"]),
    .library(name: "DatabaseLive", targets: ["DatabaseLive"]),
    .library(name: "DictionaryClient", targets: ["DictionaryClient"]),
    .library(name: "DictionaryFileClient", targets: ["DictionaryFileClient"]),
    .library(name: "DictionarySqliteClient", targets: ["DictionarySqliteClient"]),
    .library(name: "EnvVars", targets: ["EnvVars"]),
    .library(name: "FirstPartyMocks", targets: ["FirstPartyMocks"]),
    .library(name: "MailgunClient", targets: ["MailgunClient"]),
    .library(name: "MiddlewareHelpers", targets: ["MiddlewareHelpers"]),
    .library(name: "PuzzleGen", targets: ["PuzzleGen"]),
    .library(name: "RunnerTasks", targets: ["RunnerTasks"]),
    .library(name: "ServerConfig", targets: ["ServerConfig"]),
    .library(name: "ServerRouter", targets: ["ServerRouter"]),
    .library(name: "ServerRoutes", targets: ["ServerRoutes"]),
    .library(name: "SharedModels", targets: ["SharedModels"]),
    .library(name: "SnsClient", targets: ["SnsClient"]),
    .library(name: "SnsClientLive", targets: ["SnsClientLive"]),
    .library(name: "Sqlite", targets: ["Sqlite"]),
    .library(name: "TestHelpers", targets: ["TestHelpers"]),
    .library(name: "XCTestDebugSupport", targets: ["XCTestDebugSupport"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-crypto.git", from: "1.1.2"),
    .package(url: "https://github.com/crspybits/SwiftAWSSignatureV4", from: "1.1.0"),
    .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "0.1.1"),
    .package(url: "https://github.com/pointfreeco/swift-gen.git", .exact("0.3.0")),
    .package(url: "https://github.com/pointfreeco/swift-tagged.git", .branch("iso")),
    .package(url: "https://github.com/swift-server/swift-backtrace.git", .exact("1.2.0")),
    .package(url: "https://github.com/vapor/postgres-kit", .exact("2.2.0")),
    .package(
      name: "Overture", url: "https://github.com/pointfreeco/swift-overture.git", .exact("0.5.0")),
    .package(
      name: "Prelude", url: "https://github.com/pointfreeco/swift-prelude.git", .revision("9240a1f")
    ),
    .package(
      name: "Web", url: "https://github.com/pointfreeco/swift-web.git", .revision("616f365")),
    .package(
      name: "SnapshotTesting", url: "https://github.com/pointfreeco/swift-snapshot-testing.git",
      .exact("1.8.2")),
  ],
  targets: [
    .target(
      name: "AnyComparable"
    ),
    .target(
      name: "Build",
      dependencies: [
        "XCTestDebugSupport"
      ]
    ),
    .systemLibrary(
      name: "Csqlite3",
      providers: [
        .apt(["libsqlite3-dev"]),
        .brew(["sqlite3"]),
      ]
    ),
    .target(
      name: "DatabaseClient",
      dependencies: [
        "SharedModels",
        "SnsClient",
        "XCTestDebugSupport",
        .product(name: "Either", package: "Prelude"),
      ]
    ),
    .target(
      name: "DatabaseLive",
      dependencies: [
        "DatabaseClient",
        .product(name: "CasePaths", package: "swift-case-paths"),
        .product(name: "Overture", package: "Overture"),
        .product(name: "Prelude", package: "Prelude"),
        .product(name: "PostgresKit", package: "postgres-kit"),
      ]
    ),
    .testTarget(
      name: "DatabaseLiveTests",
      dependencies: [
        "DatabaseLive",
        "FirstPartyMocks",
        "TestHelpers",
      ]
    ),
    .target(
      name: "DictionaryClient",
      dependencies: [
        "SharedModels",
        "XCTestDebugSupport",
      ]
    ),
    .target(
      name: "DictionaryFileClient",
      dependencies: [
        "DictionaryClient",
        "Gzip",
        "PuzzleGen",
      ],
      resources: [.copy("Dictionaries/")]
    ),
    .testTarget(
      name: "DictionaryFileClientTests",
      dependencies: [
        "DictionaryFileClient"
      ]
    ),
    .target(
      name: "DictionarySqliteClient",
      dependencies: [
        "DictionaryClient",
        "PuzzleGen",
        "Sqlite",
      ],
      resources: [.copy("Dictionaries/")]
    ),
    .testTarget(
      name: "DictionarySqliteClientTests",
      dependencies: [
        "DictionarySqliteClient"
      ]
    ),
    .target(
      name: "EnvVars",
      dependencies: [
        "SnsClient",
        .product(name: "Tagged", package: "swift-tagged"),
      ]
    ),
    .target(
      name: "FirstPartyMocks"
    ),
    .target(
      name: "Gzip",
      dependencies: [
        "system-zlib"
      ]
    ),
    .testTarget(
      name: "LeaderboardMiddlewareIntegrationTests",
      dependencies: [
        "DatabaseLive",
        "LeaderboardMiddleware",
        "SharedModels",
        "ServerRouter",
        "SiteMiddleware",
        .product(name: "HttpPipeline", package: "Web"),
        .product(name: "HttpPipelineTestSupport", package: "Web"),
        .product(name: "Prelude", package: "Prelude"),
        .product(name: "SnapshotTesting", package: "SnapshotTesting"),
      ],
      exclude: [
        "__Snapshots__"
      ]
    ),
    .target(
      name: "MailgunClient",
      dependencies: [
        .product(name: "Either", package: "Prelude"),
        .product(name: "Tagged", package: "swift-tagged"),
        .product(name: "UrlFormEncoding", package: "Web"),
      ]
    ),
    .target(
      name: "MiddlewareHelpers",
      dependencies: [
        "EnvVars",
        .product(name: "HttpPipeline", package: "Web"),
      ]
    ),
    .target(
      name: "PuzzleGen",
      dependencies: [
        "SharedModels",
        .product(name: "Gen", package: "swift-gen"),
      ]
    ),
    .target(
      name: "ServerConfig"
    ),
    .target(
      name: "ServerRouter",
      dependencies: [
        "ServerRoutes",
        "SharedModels",
        .product(name: "ApplicativeRouter", package: "Web"),
        .product(name: "Tagged", package: "swift-tagged"),
      ]
    ),
    .target(
      name: "ServerRoutes",
      dependencies: [
        "SharedModels"
      ]
    ),
    .testTarget(
      name: "ServerRouterTests",
      dependencies: [
        "FirstPartyMocks",
        "ServerRouter",
        "TestHelpers",
        .product(name: "Overture", package: "Overture"),
      ]
    ),
    .target(
      name: "SnsClient",
      dependencies: [
        .product(name: "Either", package: "Prelude"),
        .product(name: "Tagged", package: "swift-tagged"),
      ]
    ),
    .testTarget(
      name: "SnsClientTests",
      dependencies: [
        "SnsClient",
        .product(name: "SnapshotTesting", package: "SnapshotTesting"),
      ]
    ),
    .target(
      name: "SnsClientLive",
      dependencies: [
        "SnsClient",
        .product(name: "SwiftAWSSignatureV4", package: "SwiftAWSSignatureV4"),
      ]
    ),
    .target(
      name: "Sqlite",
      dependencies: [
        .target(name: "Csqlite3")
      ]
    ),
    .target(
      name: "SharedModels",
      dependencies: [
        "FirstPartyMocks",
        .product(name: "Tagged", package: "swift-tagged"),
      ]
    ),
    .testTarget(
      name: "SharedModelsTests",
      dependencies: [
        "FirstPartyMocks",
        "SharedModels",
        "TestHelpers",
        .product(name: "Overture", package: "Overture"),
        .product(name: "SnapshotTesting", package: "SnapshotTesting"),
      ],
      exclude: [
        "__Snapshots__"
      ]
    ),
    .target(
      name: "system-zlib"
    ),
    .target(
      name: "TestHelpers"
    ),
    .target(
      name: "VerifyReceiptMiddleware",
      dependencies: [
        "DatabaseClient",
        "MiddlewareHelpers",
        "ServerRouter",
        "SharedModels",
        .product(name: "HttpPipeline", package: "Web"),
        .product(name: "Overture", package: "Overture"),
      ]
    ),
    .testTarget(
      name: "VerifyReceiptMiddlewareTests",
      dependencies: [
        "VerifyReceiptMiddleware",
        "SiteMiddleware",
        .product(name: "HttpPipelineTestSupport", package: "Web"),
        .product(name: "SnapshotTesting", package: "SnapshotTesting"),
      ],
      exclude: ["__Snapshots__"]
    ),
    .target(
      name: "XCTestDebugSupport"
    ),
  ]
)

// MARK: - client
if ProcessInfo.processInfo.environment["TEST_SERVER"] == nil {
  package.dependencies.append(contentsOf: [
    .package(
      url: "https://github.com/pointfreeco/swift-composable-architecture.git", .branch("iso"))
  ])
  package.products.append(contentsOf: [
    .library(name: "ActiveGamesFeature", targets: ["ActiveGamesFeature"]),
    .library(name: "ApiClient", targets: ["ApiClient"]),
    .library(name: "ApiClientLive", targets: ["ApiClientLive"]),
    .library(name: "AppAudioLibrary", targets: ["AppAudioLibrary"]),
    .library(name: "AppClipAudioLibrary", targets: ["AppClipAudioLibrary"]),
    .library(name: "AppFeature", targets: ["AppFeature"]),
    .library(name: "AudioPlayerClient", targets: ["AudioPlayerClient"]),
    .library(name: "BottomMenu", targets: ["BottomMenu"]),
    .library(name: "ClientModels", targets: ["ClientModels"]),
    .library(name: "CombineHelpers", targets: ["CombineHelpers"]),
    .library(name: "ComposableGameCenter", targets: ["ComposableGameCenter"]),
    .library(name: "ComposableGameCenterHelpers", targets: ["ComposableGameCenterHelpers"]),
    .library(name: "ComposableStoreKit", targets: ["ComposableStoreKit"]),
    .library(name: "ComposableUserNotifications", targets: ["ComposableUserNotifications"]),
    .library(name: "CubeCore", targets: ["CubeCore"]),
    .library(name: "CubePreview", targets: ["CubePreview"]),
    .library(name: "DailyChallengeFeature", targets: ["DailyChallengeFeature"]),
    .library(name: "DailyChallengeHelpers", targets: ["DailyChallengeHelpers"]),
    .library(name: "DateHelpers", targets: ["DateHelpers"]),
    .library(name: "DemoFeature", targets: ["DemoFeature"]),
    .library(name: "DeviceId", targets: ["DeviceId"]),
    .library(name: "FeedbackGeneratorClient", targets: ["FeedbackGeneratorClient"]),
    .library(name: "FileClient", targets: ["FileClient"]),
    .library(name: "GameCore", targets: ["GameCore"]),
    .library(name: "GameFeature", targets: ["GameFeature"]),
    .library(name: "GameOverFeature", targets: ["GameOverFeature"]),
    .library(name: "HomeFeature", targets: ["HomeFeature"]),
    .library(name: "IntegrationTestHelpers", targets: ["IntegrationTestHelpers"]),
    .library(name: "LeaderboardFeature", targets: ["LeaderboardFeature"]),
    .library(name: "LocalDatabaseClient", targets: ["LocalDatabaseClient"]),
    .library(name: "LowPowerModeClient", targets: ["LowPowerModeClient"]),
    .library(name: "MultiplayerFeature", targets: ["MultiplayerFeature"]),
    .library(name: "NotificationHelpers", targets: ["NotificationHelpers"]),
    .library(name: "NotificationsAuthAlert", targets: ["NotificationsAuthAlert"]),
    .library(name: "OnboardingFeature", targets: ["OnboardingFeature"]),
    .library(name: "RemoteNotificationsClient", targets: ["RemoteNotificationsClient"]),
    .library(name: "ServerConfigClient", targets: ["ServerConfigClient"]),
    .library(name: "SettingsFeature", targets: ["SettingsFeature"]),
    .library(name: "SharedSwiftUIEnvironment", targets: ["SharedSwiftUIEnvironment"]),
    .library(name: "SoloFeature", targets: ["SoloFeature"]),
    .library(name: "StatsFeature", targets: ["StatsFeature"]),
    .library(name: "Styleguide", targets: ["Styleguide"]),
    .library(name: "SwiftUIHelpers", targets: ["SwiftUIHelpers"]),
    .library(name: "TcaHelpers", targets: ["TcaHelpers"]),
    .library(name: "TrailerFeature", targets: ["TrailerFeature"]),
    .library(name: "UIApplicationClient", targets: ["UIApplicationClient"]),
    .library(name: "UpgradeInterstitialFeature", targets: ["UpgradeInterstitialFeature"]),
    .library(name: "UserDefaultsClient", targets: ["UserDefaultsClient"]),
    .library(name: "VocabFeature", targets: ["VocabFeature"]),
  ])
  package.targets.append(contentsOf: [
    .target(
      name: "ActiveGamesFeature",
      dependencies: [
        "AnyComparable",
        "ClientModels",
        "ComposableGameCenter",
        "DateHelpers",
        "SharedModels",
        "Styleguide",
        "TcaHelpers",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "ApiClient",
      dependencies: [
        "ServerRoutes",
        "SharedModels",
        "XCTestDebugSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ],
      exclude: ["Secrets.swift.example"]
    ),
    .target(
      name: "ApiClientLive",
      dependencies: [
        "ApiClient",
        "ServerRouter",
        "SharedModels",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Overture", package: "Overture"),
        .product(name: "Tagged", package: "swift-tagged"),
      ],
      exclude: ["Secrets.swift.example"]
    ),
    .target(
      name: "AppAudioLibrary",
      resources: [.process("Resources/")]
    ),
    .target(
      name: "AppClipAudioLibrary",
      resources: [.process("Resources/")]
    ),
    .target(
      name: "AppFeature",
      dependencies: [
        "ApiClient",
        "AudioPlayerClient",
        "Build",
        "ClientModels",
        "ComposableGameCenter",
        "ComposableGameCenterHelpers",
        "ComposableStoreKit",
        "CubeCore",
        "CubePreview",
        "DailyChallengeFeature",
        "DeviceId",
        "DictionarySqliteClient",
        "FeedbackGeneratorClient",
        "FileClient",
        "GameFeature",
        "GameOverFeature",
        "HomeFeature",
        "LeaderboardFeature",
        "LocalDatabaseClient",
        "LowPowerModeClient",
        "MultiplayerFeature",
        "NotificationHelpers",
        "OnboardingFeature",
        "RemoteNotificationsClient",
        "ServerRouter",
        "SettingsFeature",
        "SharedModels",
        "SoloFeature",
        "StatsFeature",
        "TcaHelpers",
        "UIApplicationClient",
        "VocabFeature",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Gen", package: "swift-gen"),
        .product(name: "Tagged", package: "swift-tagged"),
      ]
    ),
    .testTarget(
      name: "AppFeatureTests",
      dependencies: [
        "AppFeature",
        "TestHelpers",
        .product(name: "SnapshotTesting", package: "SnapshotTesting"),
      ]
    ),
    .testTarget(
      name: "AppStoreSnapshotTests",
      dependencies: [
        "AppFeature",
        "SharedSwiftUIEnvironment",
        "TestHelpers",
        .product(name: "SnapshotTesting", package: "SnapshotTesting"),
      ],
      exclude: [
        "__Snapshots__"
      ],
      resources: [.process("Resources/")]
    ),
    .target(
      name: "AudioPlayerClient",
      dependencies: [
        "XCTestDebugSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "BottomMenu",
      dependencies: [
        "Styleguide",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "ClientModels",
      dependencies: [
        "ComposableGameCenter",
        "SharedModels",
      ]
    ),
    .testTarget(
      name: "ClientModelsTests",
      dependencies: [
        "ClientModels",
        "FirstPartyMocks",
        "TestHelpers",
        .product(name: "Overture", package: "Overture"),
        .product(name: "SnapshotTesting", package: "SnapshotTesting"),
      ],
      exclude: [
        "__Snapshots__"
      ]
    ),
    .target(
      name: "CombineHelpers"
    ),
    .target(
      name: "ComposableGameCenter",
      dependencies: [
        "CombineHelpers",
        "FirstPartyMocks",
        "XCTestDebugSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Overture", package: "Overture"),
        .product(name: "Tagged", package: "swift-tagged"),
      ]
    ),
    .target(
      name: "ComposableGameCenterHelpers",
      dependencies: ["ComposableGameCenter"]
    ),
    .target(
      name: "ComposableStoreKit",
      dependencies: [
        "XCTestDebugSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "ComposableUserNotifications",
      dependencies: [
        "XCTestDebugSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "CubeCore",
      dependencies: [
        "ClientModels",
        "SharedModels",
        "Styleguide",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Gen", package: "swift-gen"),
      ],
      resources: [.process("Resources/")]
    ),
    .target(
      name: "CubePreview",
      dependencies: [
        "CubeCore",
        "SharedModels",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "CubePreviewTests",
      dependencies: [
        "CubePreview",
        "TestHelpers",
      ]
    ),
    .target(
      name: "DailyChallengeFeature",
      dependencies: [
        "ApiClient",
        "ComposableUserNotifications",
        "CubePreview",
        "DailyChallengeHelpers",
        "DateHelpers",
        "LeaderboardFeature",
        "Overture",
        "NotificationHelpers",
        "NotificationsAuthAlert",
        "RemoteNotificationsClient",
        "SharedModels",
        "Styleguide",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "DailyChallengeFeatureIntegrationTests",
      dependencies: [
        "DailyChallengeFeature",
        "IntegrationTestHelpers",
        "SiteMiddleware",
        "TestHelpers",
      ]
    ),
    .testTarget(
      name: "DailyChallengeFeatureTests",
      dependencies: [
        "DailyChallengeFeature",
        "TestHelpers",
        .product(name: "SnapshotTesting", package: "SnapshotTesting"),
      ],
      exclude: ["__Snapshots__"]
    ),
    .target(
      name: "DailyChallengeHelpers",
      dependencies: [
        "ApiClient",
        "FileClient",
        "SharedModels",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "DateHelpers"
    ),
    .target(
      name: "DemoFeature",
      dependencies: [
        "ApiClient",
        "Build",
        "CubeCore",
        "GameCore",
        "DictionaryClient",
        "FeedbackGeneratorClient",
        "LowPowerModeClient",
        "OnboardingFeature",
        "SharedModels",
        "UserDefaultsClient",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "DeviceId",
      dependencies: [
        "XCTestDebugSupport"
      ]
    ),
    .target(
      name: "FeedbackGeneratorClient",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
      ]
    ),
    .target(
      name: "FileClient",
      dependencies: [
        "ClientModels",
        "CombineHelpers",
        "XCTestDebugSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "GameCore",
      dependencies: [
        "ActiveGamesFeature",
        "ApiClient",
        "AudioPlayerClient",
        "BottomMenu",
        "Build",
        "ClientModels",
        "ComposableGameCenter",
        "ComposableUserNotifications",
        "CubeCore",
        "DictionaryClient",
        "GameOverFeature",
        "FeedbackGeneratorClient",
        "FileClient",
        "LowPowerModeClient",
        "PuzzleGen",
        "RemoteNotificationsClient",
        "SharedSwiftUIEnvironment",
        "Styleguide",
        "TcaHelpers",
        "UIApplicationClient",
        "UpgradeInterstitialFeature",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ],
      resources: [.process("Resources/")]
    ),
    .testTarget(
      name: "GameCoreTests",
      dependencies: [
        "GameCore",
        "TestHelpers",
      ]
    ),
    .target(
      name: "GameFeature",
      dependencies: [
        "ActiveGamesFeature",
        "ApiClient",
        "AudioPlayerClient",
        "BottomMenu",
        "ClientModels",
        "ComposableGameCenter",
        "ComposableUserNotifications",
        "CubeCore",
        "DictionaryClient",
        "GameCore",
        "GameOverFeature",
        "FeedbackGeneratorClient",
        "FileClient",
        "LowPowerModeClient",
        "PuzzleGen",
        "RemoteNotificationsClient",
        "SettingsFeature",
        "Styleguide",
        "TcaHelpers",
        "UIApplicationClient",
        "UpgradeInterstitialFeature",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "GameFeatureTests",
      dependencies: [
        "AppFeature",
        "TestHelpers",
        .product(name: "Gen", package: "swift-gen"),
        .product(name: "SnapshotTesting", package: "SnapshotTesting"),
      ],
      exclude: ["__Snapshots__"],
      resources: [.process("Resources/")]
    ),
    .target(
      name: "GameOverFeature",
      dependencies: [
        "ApiClient",
        "AudioPlayerClient",
        "ClientModels",
        "CombineHelpers",
        "ComposableStoreKit",
        "DailyChallengeHelpers",
        "FileClient",
        "FirstPartyMocks",
        "LocalDatabaseClient",
        "NotificationHelpers",
        "NotificationsAuthAlert",
        "SharedModels",
        "SharedSwiftUIEnvironment",
        "SwiftUIHelpers",
        "TcaHelpers",
        "UpgradeInterstitialFeature",
        "UserDefaultsClient",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "GameOverFeatureTests",
      dependencies: [
        "FirstPartyMocks",
        "GameOverFeature",
        "SharedSwiftUIEnvironment",
        "TestHelpers",
        .product(name: "SnapshotTesting", package: "SnapshotTesting"),
      ],
      exclude: ["__Snapshots__"],
      resources: [.process("Resources/")]
    ),
    .testTarget(
      name: "GameOverFeatureIntegrationTests",
      dependencies: [
        "GameOverFeature",
        "IntegrationTestHelpers",
        "SiteMiddleware",
      ]
    ),
    .target(
      name: "HomeFeature",
      dependencies: [
        "ActiveGamesFeature",
        "ApiClient",
        "AudioPlayerClient",
        "Build",
        "ClientModels",
        "CombineHelpers",
        "ComposableGameCenterHelpers",
        "ComposableStoreKit",
        "ComposableUserNotifications",
        "DailyChallengeFeature",
        "DateHelpers",
        "DeviceId",
        "FileClient",
        "LeaderboardFeature",
        "LocalDatabaseClient",
        "MultiplayerFeature",
        "ServerConfigClient",
        "SettingsFeature",
        "SharedModels",
        "SoloFeature",
        "Styleguide",
        "SwiftUIHelpers",
        "TcaHelpers",
        "UIApplicationClient",
        "UpgradeInterstitialFeature",
        "UserDefaultsClient",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Overture", package: "Overture"),
      ]
    ),
    .testTarget(
      name: "HomeFeatureTests",
      dependencies: [
        "HomeFeature",
        .product(name: "SnapshotTesting", package: "SnapshotTesting"),
      ],
      exclude: ["__Snapshots__"]
    ),
    .target(
      name: "IntegrationTestHelpers",
      dependencies: [
        "ApiClient",
        "ServerRouter",
        "TestHelpers",
        .product(name: "HttpPipeline", package: "Web"),
      ]
    ),
    .target(
      name: "LeaderboardFeature",
      dependencies: [
        "ApiClient",
        "CubePreview",
        "Styleguide",
        "SwiftUIHelpers",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Overture", package: "Overture"),
      ]
    ),
    .testTarget(
      name: "LeaderboardFeatureTests",
      dependencies: [
        "LeaderboardFeature",
        "IntegrationTestHelpers",
        "SiteMiddleware",
      ]
    ),
    .target(
      name: "LocalDatabaseClient",
      dependencies: [
        "SharedModels",
        "Sqlite",
        "XCTestDebugSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Overture", package: "Overture"),
      ]
    ),
    .target(
      name: "LowPowerModeClient",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
      ]
    ),
    .target(
      name: "MultiplayerFeature",
      dependencies: [
        "ClientModels",
        "ComposableGameCenter",
        "Styleguide",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "NotificationHelpers",
      dependencies: [
        "ComposableUserNotifications",
        "RemoteNotificationsClient",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "NotificationsAuthAlert",
      dependencies: [
        "CombineHelpers",
        "ComposableUserNotifications",
        "NotificationHelpers",
        "RemoteNotificationsClient",
        "Styleguide",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "OnboardingFeature",
      dependencies: [
        "CubeCore",
        "GameCore",
        "DictionaryClient",
        "FeedbackGeneratorClient",
        "LowPowerModeClient",
        "PuzzleGen",
        "SharedModels",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "OnboardingFeatureTests",
      dependencies: [
        "OnboardingFeature"
      ]
    ),
    .target(
      name: "RemoteNotificationsClient",
      dependencies: [
        "XCTestDebugSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "ServerConfigClient",
      dependencies: [
        "ServerConfig",
        "XCTestDebugSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "SettingsFeature",
      dependencies: [
        "ApiClient",
        "AudioPlayerClient",
        "Build",
        "ComposableStoreKit",
        "ComposableUserNotifications",
        "FileClient",
        "LocalDatabaseClient",
        "RemoteNotificationsClient",
        "ServerConfigClient",
        "StatsFeature",
        "Styleguide",
        "SwiftUIHelpers",
        "TcaHelpers",
        "UIApplicationClient",
        "UserDefaultsClient",
        "XCTestDebugSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ],
      resources: [.process("Resources/")]
    ),
    .testTarget(
      name: "SettingsFeatureTests",
      dependencies: [
        "TestHelpers",
        "SettingsFeature",
        .product(name: "SnapshotTesting", package: "SnapshotTesting"),
      ],
      exclude: ["__Snapshots__"]
    ),
    .target(
      name: "SharedSwiftUIEnvironment"
    ),
    .target(
      name: "SoloFeature",
      dependencies: [
        "ClientModels",
        "FileClient",
        "SharedModels",
        "Styleguide",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "StatsFeature",
      dependencies: [
        "LocalDatabaseClient",
        "Styleguide",
        "VocabFeature",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "Styleguide",
      dependencies: [
        "SwiftUIHelpers",
        .product(name: "Tagged", package: "swift-tagged"),
      ],
      resources: [
        .process("Fonts")
      ]
    ),
    .target(
      name: "SwiftUIHelpers",
      dependencies: [
        .product(name: "Gen", package: "swift-gen")
      ]
    ),
    .target(
      name: "TcaHelpers",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
      ]
    ),
    .target(
      name: "TrailerFeature",
      dependencies: [
        "ApiClient",
        "CubeCore",
        "GameCore",
        "DictionaryClient",
        "FeedbackGeneratorClient",
        "LowPowerModeClient",
        "OnboardingFeature",
        "SharedModels",
        "UserDefaultsClient",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "UIApplicationClient",
      dependencies: [
        "XCTestDebugSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "UpgradeInterstitialFeature",
      dependencies: [
        "CombineHelpers",
        "ComposableStoreKit",
        "ServerConfigClient",
        "Styleguide",
        "SwiftUIHelpers",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "UpgradeInterstitialFeatureTests",
      dependencies: [
        "FirstPartyMocks",
        "UpgradeInterstitialFeature",
        .product(name: "Overture", package: "Overture"),
        .product(name: "SnapshotTesting", package: "SnapshotTesting"),
      ],
      exclude: ["__Snapshots__"]
    ),
    .target(
      name: "UserDefaultsClient",
      dependencies: [
        "XCTestDebugSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "VocabFeature",
      dependencies: [
        "CubePreview",
        "LocalDatabaseClient",
        "SharedModels",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
  ])
}

// MARK: - server
package.products.append(contentsOf: [
  .executable(name: "daily-challenge-reports", targets: ["daily-challenge-reports"]),
  .executable(name: "runner", targets: ["runner"]),
  .executable(name: "server", targets: ["server"]),
  .library(name: "AppSiteAssociationMiddleware", targets: ["AppSiteAssociationMiddleware"]),
  .library(name: "DailyChallengeMiddleware", targets: ["DailyChallengeMiddleware"]),
  .library(name: "DailyChallengeReports", targets: ["DailyChallengeReports"]),
  .library(name: "DemoMiddleware", targets: ["DemoMiddleware"]),
  .library(name: "LeaderboardMiddleware", targets: ["LeaderboardMiddleware"]),
  .library(name: "PushMiddleware", targets: ["PushMiddleware"]),
  .library(name: "ServerBootstrap", targets: ["ServerBootstrap"]),
  .library(name: "ServerConfigMiddleware", targets: ["ServerConfigMiddleware"]),
  .library(name: "ShareGameMiddleware", targets: ["ShareGameMiddleware"]),
  .library(name: "SiteMiddleware", targets: ["SiteMiddleware"]),
  .library(name: "VerifyReceiptMiddleware", targets: ["VerifyReceiptMiddleware"]),
])
package.targets.append(contentsOf: [
  .target(
    name: "AppSiteAssociationMiddleware",
    dependencies: [
      .product(name: "HttpPipeline", package: "Web")
    ]
  ),
  .testTarget(
    name: "AppSiteAssociationMiddlewareTests",
    dependencies: [
      "AppSiteAssociationMiddleware",
      "SiteMiddleware",
      .product(name: "HttpPipelineTestSupport", package: "Web"),
      .product(name: "SnapshotTesting", package: "SnapshotTesting"),
    ]
  ),
  .target(
    name: "daily-challenge-reports",
    dependencies: [
      "DailyChallengeReports"
    ]
  ),
  .target(
    name: "DailyChallengeMiddleware",
    dependencies: [
      "DatabaseClient",
      "MiddlewareHelpers",
      "SharedModels",
      .product(name: "HttpPipeline", package: "Web"),
    ]
  ),
  .testTarget(
    name: "DailyChallengeMiddlewareTests",
    dependencies: [
      "FirstPartyMocks",
      "DailyChallengeMiddleware",
      "SharedModels",
      "SiteMiddleware",
      .product(name: "HttpPipeline", package: "Web"),
      .product(name: "HttpPipelineTestSupport", package: "Web"),
      .product(name: "SnapshotTesting", package: "SnapshotTesting"),
    ],
    exclude: ["__Snapshots__"]
  ),
  .target(
    name: "DailyChallengeReports",
    dependencies: [
      "ServerBootstrap"
    ]
  ),
  .testTarget(
    name: "DailyChallengeReportsTests",
    dependencies: [
      "DailyChallengeReports"
    ]
  ),
  .target(
    name: "DemoMiddleware",
    dependencies: [
      "DatabaseClient",
      "MiddlewareHelpers",
      "ServerRoutes",
      "SharedModels",
      .product(name: "HttpPipeline", package: "Web"),
    ]
  ),
  .testTarget(
    name: "DemoMiddlewareTests",
    dependencies: [
      "DemoMiddleware",
      "SiteMiddleware",
      .product(name: "HttpPipelineTestSupport", package: "Web"),
      .product(name: "SnapshotTesting", package: "SnapshotTesting"),
    ]
  ),
  .target(
    name: "LeaderboardMiddleware",
    dependencies: [
      "DatabaseClient",
      "DictionaryClient",
      "MiddlewareHelpers",
      "ServerRouter",
      .product(name: "CasePaths", package: "swift-case-paths"),
      .product(name: "HttpPipeline", package: "Web"),
    ]
  ),
  .testTarget(
    name: "LeaderboardMiddlewareTests",
    dependencies: [
      "LeaderboardMiddleware",
      "SiteMiddleware",
      .product(name: "HttpPipelineTestSupport", package: "Web"),
      .product(name: "SnapshotTesting", package: "SnapshotTesting"),
    ],
    exclude: ["__Snapshots__"]
  ),
  .target(
    name: "PushMiddleware",
    dependencies: [
      "DatabaseClient",
      "SharedModels",
      "SnsClient",
      .product(name: "Either", package: "Prelude"),
      .product(name: "HttpPipeline", package: "Web"),
      .product(name: "Prelude", package: "Prelude"),
    ]
  ),
  .testTarget(
    name: "PushMiddlewareTests",
    dependencies: [
      "DatabaseClient",
      "PushMiddleware",
      "ServerRouter",
      "SharedModels",
      "SiteMiddleware",
      .product(name: "Either", package: "Prelude"),
      .product(name: "HttpPipeline", package: "Web"),
      .product(name: "HttpPipelineTestSupport", package: "Web"),
      .product(name: "Overture", package: "Overture"),
      .product(name: "Prelude", package: "Prelude"),
      .product(name: "SnapshotTesting", package: "SnapshotTesting"),
    ]
  ),
  .target(
    name: "runner",
    dependencies: [
      "RunnerTasks"
    ]
  ),
  .target(
    name: "RunnerTasks",
    dependencies: [
      "ServerBootstrap"
    ]
  ),
  .testTarget(
    name: "RunnerTests",
    dependencies: [
      "FirstPartyMocks",
      "RunnerTasks",
    ]
  ),
  .target(
    name: "server",
    dependencies: [
      "ServerBootstrap",
      "SiteMiddleware",
      .product(name: "HttpPipeline", package: "Web"),
    ]
  ),
  .target(
    name: "ServerBootstrap",
    dependencies: [
      "DatabaseLive",
      "DictionarySqliteClient",
      "EnvVars",
      "SiteMiddleware",
      "SnsClientLive",
      .product(name: "Backtrace", package: "swift-backtrace"),
      .product(name: "Crypto", package: "swift-crypto"),
    ]
  ),
  .target(
    name: "ServerConfigMiddleware",
    dependencies: [
      "ServerConfig",
      "SharedModels",
      .product(name: "HttpPipeline", package: "Web"),
    ]
  ),
  .testTarget(
    name: "ServerConfigMiddlewareTests",
    dependencies: [
      "ServerConfigMiddleware",
      "SiteMiddleware",
      .product(name: "Either", package: "Prelude"),
      .product(name: "HttpPipeline", package: "Web"),
      .product(name: "HttpPipelineTestSupport", package: "Web"),
      .product(name: "Prelude", package: "Prelude"),
      .product(name: "SnapshotTesting", package: "SnapshotTesting"),
    ],
    exclude: ["__Snapshots__"]
  ),
  .target(
    name: "ShareGameMiddleware",
    dependencies: [
      "DatabaseClient",
      "EnvVars",
      "MiddlewareHelpers",
      "ServerRouter",
      "SharedModels",
      .product(name: "HttpPipeline", package: "Web"),
    ]
  ),
  .testTarget(
    name: "ShareGameMiddlewareTests",
    dependencies: [
      "ShareGameMiddleware",
      "SiteMiddleware",
      "TestHelpers",
      .product(name: "HttpPipelineTestSupport", package: "Web"),
      .product(name: "SnapshotTesting", package: "SnapshotTesting"),
    ],
    exclude: ["__Snapshots__"]
  ),
  .target(
    name: "SiteMiddleware",
    dependencies: [
      "AppSiteAssociationMiddleware",
      "DailyChallengeMiddleware",
      "DatabaseClient",
      "DemoMiddleware",
      "EnvVars",
      "LeaderboardMiddleware",
      "MailgunClient",
      "MiddlewareHelpers",
      "PushMiddleware",
      "ServerConfigMiddleware",
      "SharedModels",
      "ShareGameMiddleware",
      "SnsClient",
      "VerifyReceiptMiddleware",
      .product(name: "ApplicativeRouterHttpPipelineSupport", package: "Web"),
      .product(name: "HttpPipeline", package: "Web"),
      .product(name: "Overture", package: "Overture"),
    ],
    resources: [.process("Resources/")]
  ),
  .testTarget(
    name: "SiteMiddlewareTests",
    dependencies: [
      "FirstPartyMocks",
      "SiteMiddleware",
      "TestHelpers",
      .product(name: "HttpPipelineTestSupport", package: "Web"),
      .product(name: "SnapshotTesting", package: "SnapshotTesting"),
    ],
    exclude: ["__Snapshots__"]
  ),
])
