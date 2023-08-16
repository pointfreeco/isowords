// swift-tools-version:5.7

import Foundation
import PackageDescription

// MARK: - shared
var package = Package(
  name: "isowords",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
    .tvOS(.v16),
    .watchOS(.v9),
  ],
  products: [
    .library(name: "Build", targets: ["Build"]),
    .library(name: "DictionaryClient", targets: ["DictionaryClient"]),
    .library(name: "DictionarySqliteClient", targets: ["DictionarySqliteClient"]),
    .library(name: "FirstPartyMocks", targets: ["FirstPartyMocks"]),
    .library(name: "PuzzleGen", targets: ["PuzzleGen"]),
    .library(name: "ServerConfig", targets: ["ServerConfig"]),
    .library(name: "ServerRouter", targets: ["ServerRouter"]),
    .library(name: "SharedModels", targets: ["SharedModels"]),
    .library(name: "Sqlite", targets: ["Sqlite"]),
    .library(name: "TestHelpers", targets: ["TestHelpers"]),
    .library(name: "XCTestDebugSupport", targets: ["XCTestDebugSupport"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-crypto", from: "1.1.6"),
    .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.1.0"),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-gen", from: "0.3.0"),
    .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.12.0"),
    .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.6.0"),
    .package(url: "https://github.com/pointfreeco/swift-url-routing", from: "0.2.0"),
    .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-overture", from: "0.5.0"),
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.10.0"),
  ],
  targets: [
    .target(
      name: "Build",
      dependencies: [
        .product(name: "Dependencies", package: "swift-composable-architecture"),
        .product(name: "Tagged", package: "swift-tagged"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
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
      name: "DictionaryClient",
      dependencies: [
        "SharedModels",
        .product(name: "Dependencies", package: "swift-composable-architecture"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
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
      name: "FirstPartyMocks"
    ),
    .testTarget(
      name: "LeaderboardMiddlewareIntegrationTests",
      dependencies: [
        "DatabaseLive",
        "LeaderboardMiddleware",
        "SharedModels",
        "ServerRouter",
        "SiteMiddleware",
        .product(name: "HttpPipeline", package: "swift-web"),
        .product(name: "HttpPipelineTestSupport", package: "swift-web"),
        .product(name: "Prelude", package: "swift-prelude"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      exclude: [
        "__Snapshots__"
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
      name: "ServerConfig",
      dependencies: [
        "Build"
      ]
    ),
    .target(
      name: "ServerRouter",
      dependencies: [
        "SharedModels",
        .product(name: "Tagged", package: "swift-tagged"),
        .product(name: "Parsing", package: "swift-parsing"),
        .product(name: "URLRouting", package: "swift-url-routing"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
      ]
    ),
    .testTarget(
      name: "ServerRouterTests",
      dependencies: [
        "FirstPartyMocks",
        "ServerRouter",
        "TestHelpers",
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "Overture", package: "swift-overture"),
        .product(name: "Parsing", package: "swift-parsing"),
        .product(name: "URLRouting", package: "swift-url-routing"),
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
        "Build",
        "FirstPartyMocks",
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "Tagged", package: "swift-tagged"),
      ]
    ),
    .testTarget(
      name: "SharedModelsTests",
      dependencies: [
        "FirstPartyMocks",
        "SharedModels",
        "TestHelpers",
        .product(name: "Overture", package: "swift-overture"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      exclude: [
        "__Snapshots__"
      ]
    ),
    .target(
      name: "TestHelpers"
    ),
    .target(
      name: "XCTestDebugSupport"
    ),
  ]
)

// MARK: - client
if ProcessInfo.processInfo.environment["TEST_SERVER"] == nil {
  package.products.append(contentsOf: [
    .library(name: "ActiveGamesFeature", targets: ["ActiveGamesFeature"]),
    .library(name: "AnyComparable", targets: ["AnyComparable"]),
    .library(name: "ApiClient", targets: ["ApiClient"]),
    .library(name: "ApiClientLive", targets: ["ApiClientLive"]),
    .library(name: "AppAudioLibrary", targets: ["AppAudioLibrary"]),
    .library(name: "AppClipAudioLibrary", targets: ["AppClipAudioLibrary"]),
    .library(name: "AppFeature", targets: ["AppFeature"]),
    .library(name: "AudioPlayerClient", targets: ["AudioPlayerClient"]),
    .library(name: "Bloom", targets: ["Bloom"]),
    .library(name: "BottomMenu", targets: ["BottomMenu"]),
    .library(name: "ChangelogFeature", targets: ["ChangelogFeature"]),
    .library(name: "ClientModels", targets: ["ClientModels"]),
    .library(name: "CombineHelpers", targets: ["CombineHelpers"]),
    .library(name: "ComposableGameCenter", targets: ["ComposableGameCenter"]),
    .library(name: "ComposableStoreKit", targets: ["ComposableStoreKit"]),
    .library(name: "ComposableUserNotifications", targets: ["ComposableUserNotifications"]),
    .library(name: "CubeCore", targets: ["CubeCore"]),
    .library(name: "CubePreview", targets: ["CubePreview"]),
    .library(name: "DailyChallengeFeature", targets: ["DailyChallengeFeature"]),
    .library(name: "DailyChallengeHelpers", targets: ["DailyChallengeHelpers"]),
    .library(name: "DateHelpers", targets: ["DateHelpers"]),
    .library(name: "DemoFeature", targets: ["DemoFeature"]),
    .library(name: "DeviceId", targets: ["DeviceId"]),
    .library(name: "DictionaryFileClient", targets: ["DictionaryFileClient"]),
    .library(name: "FeedbackGeneratorClient", targets: ["FeedbackGeneratorClient"]),
    .library(name: "FileClient", targets: ["FileClient"]),
    .library(name: "GameCore", targets: ["GameCore"]),
    .library(name: "GameFeature", targets: ["GameFeature"]),
    .library(name: "GameOverFeature", targets: ["GameOverFeature"]),
    .library(name: "HapticsCore", targets: ["HapticsCore"]),
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
    .library(name: "SelectionSoundsCore", targets: ["SelectionSoundsCore"]),
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
      name: "AnyComparable"
    ),
    .target(
      name: "ApiClient",
      dependencies: [
        "SharedModels",
        "XCTestDebugSupport",
        .product(name: "CasePaths", package: "swift-case-paths"),
        .product(name: "Dependencies", package: "swift-composable-architecture"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
      ]
    ),
    .target(
      name: "ApiClientLive",
      dependencies: [
        "ApiClient",
        "ServerRouter",
        "SharedModels",
        "TcaHelpers",
        .product(name: "Dependencies", package: "swift-composable-architecture"),
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
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
      ]
    ),
    .testTarget(
      name: "AppFeatureTests",
      dependencies: [
        "AppFeature",
        "TestHelpers",
      ]
    ),
    .testTarget(
      name: "AppStoreSnapshotTests",
      dependencies: [
        "AppFeature",
        "SharedSwiftUIEnvironment",
        "TestHelpers",
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      exclude: [
        "__Snapshots__"
      ],
      resources: [.process("Resources/")]
    ),
    .target(
      name: "AudioPlayerClient",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
      ]
    ),
    .target(
      name: "Bloom",
      dependencies: [
        "Styleguide",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Gen", package: "swift-gen"),
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
      name: "ChangelogFeature",
      dependencies: [
        "ApiClient",
        "Build",
        "ServerConfigClient",
        "SharedModels",
        "Styleguide",
        "SwiftUIHelpers",
        "TcaHelpers",
        "UIApplicationClient",
        "UserDefaultsClient",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Overture", package: "swift-overture"),
      ]
    ),
    .testTarget(
      name: "ChangelogFeatureTests",
      dependencies: [
        "ChangelogFeature"
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
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "Overture", package: "swift-overture"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
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
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Overture", package: "swift-overture"),
        .product(name: "Tagged", package: "swift-tagged"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
      ]
    ),
    .target(
      name: "ComposableStoreKit",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
      ]
    ),
    .target(
      name: "ComposableUserNotifications",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
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
        "AudioPlayerClient",
        "Bloom",
        "CubeCore",
        "FeedbackGeneratorClient",
        "HapticsCore",
        "LowPowerModeClient",
        "SelectionSoundsCore",
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
        "NotificationHelpers",
        "NotificationsAuthAlert",
        "RemoteNotificationsClient",
        "SharedModels",
        "Styleguide",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Overture", package: "swift-overture"),
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
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
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
        .product(name: "Dependencies", package: "swift-composable-architecture"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
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
      name: "FeedbackGeneratorClient",
      dependencies: [
        "XCTestDebugSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
      ]
    ),
    .target(
      name: "FileClient",
      dependencies: [
        "ClientModels",
        "CombineHelpers",
        "XCTestDebugSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
      ]
    ),
    .target(
      name: "GameCore",
      dependencies: [
        "ActiveGamesFeature",
        "ApiClient",
        "AudioPlayerClient",
        "Bloom",
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
        "HapticsCore",
        "LowPowerModeClient",
        "PuzzleGen",
        "RemoteNotificationsClient",
        "SelectionSoundsCore",
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
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      exclude: ["__Snapshots__"]
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
      ]
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
      name: "GameOverFeatureIntegrationTests",
      dependencies: [
        "GameOverFeature",
        "IntegrationTestHelpers",
        "SiteMiddleware",
      ]
    ),
    .testTarget(
      name: "GameOverFeatureTests",
      dependencies: [
        "FirstPartyMocks",
        "GameOverFeature",
        "SharedSwiftUIEnvironment",
        "TestHelpers",
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      exclude: ["__Snapshots__"],
      resources: [.process("Resources/")]
    ),
    .target(
      name: "Gzip",
      dependencies: [
        "system-zlib"
      ]
    ),
    .target(
      name: "HapticsCore",
      dependencies: [
        "FeedbackGeneratorClient",
        "TcaHelpers",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "HomeFeature",
      dependencies: [
        "ActiveGamesFeature",
        "ApiClient",
        "AudioPlayerClient",
        "Build",
        "ChangelogFeature",
        "ClientModels",
        "CombineHelpers",
        "ComposableStoreKit",
        "ComposableUserNotifications",
        "DailyChallengeFeature",
        "DateHelpers",
        "DeviceId",
        "FileClient",
        "LeaderboardFeature",
        "LocalDatabaseClient",
        "LowPowerModeClient",
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
        .product(name: "Overture", package: "swift-overture"),
      ]
    ),
    .testTarget(
      name: "HomeFeatureTests",
      dependencies: [
        "HomeFeature",
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      exclude: ["__Snapshots__"]
    ),
    .target(
      name: "IntegrationTestHelpers",
      dependencies: [
        "ApiClient",
        "ServerRouter",
        "TestHelpers",
        .product(name: "HttpPipeline", package: "swift-web"),
      ]
    ),
    .target(
      name: "LeaderboardFeature",
      dependencies: [
        "ApiClient",
        "AudioPlayerClient",
        "CubePreview",
        "LowPowerModeClient",
        "Styleguide",
        "SwiftUIHelpers",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Overture", package: "swift-overture"),
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
        .product(name: "Overture", package: "swift-overture"),
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
        "TcaHelpers",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "MultiplayerFeatureTests",
      dependencies: [
        "MultiplayerFeature",
        "TestHelpers",
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
      name: "SelectionSoundsCore",
      dependencies: [
        "AudioPlayerClient",
        "SharedModels",
        "TcaHelpers",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "RemoteNotificationsClient",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
      ]
    ),
    .target(
      name: "ServerConfigClient",
      dependencies: [
        "ServerConfig",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
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
        "LowPowerModeClient",
        "RemoteNotificationsClient",
        "ServerConfigClient",
        "StatsFeature",
        "Styleguide",
        "SwiftUIHelpers",
        "TcaHelpers",
        "UIApplicationClient",
        "UserDefaultsClient",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
      ],
      resources: [.process("Resources/")]
    ),
    .testTarget(
      name: "SettingsFeatureTests",
      dependencies: [
        "TestHelpers",
        "SettingsFeature",
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
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
        "AudioPlayerClient",
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
      name: "system-zlib"
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
        "Bloom",
        "CubeCore",
        "GameCore",
        "DictionaryClient",
        "FeedbackGeneratorClient",
        "LowPowerModeClient",
        "OnboardingFeature",
        "SharedModels",
        "TcaHelpers",
        "UserDefaultsClient",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "UIApplicationClient",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
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
        .product(name: "Overture", package: "swift-overture"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      exclude: ["__Snapshots__"]
    ),
    .target(
      name: "UserDefaultsClient",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
      ]
    ),
    .target(
      name: "VocabFeature",
      dependencies: [
        "AudioPlayerClient",
        "CubePreview",
        "FeedbackGeneratorClient",
        "LocalDatabaseClient",
        "LowPowerModeClient",
        "SharedModels",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
  ])
}

// MARK: - server
package.dependencies.append(contentsOf: [
  .package(url: "https://github.com/crspybits/SwiftAWSSignatureV4", from: "1.1.0"),
  .package(url: "https://github.com/swift-server/swift-backtrace", exact: "1.2.0"),
  .package(url: "https://github.com/vapor/postgres-kit", exact: "2.2.0"),
  .package(url: "https://github.com/pointfreeco/swift-prelude", revision: "7ff9911"),
  .package(url: "https://github.com/pointfreeco/swift-web", revision: "2ad82ec"),
])
package.products.append(contentsOf: [
  .executable(name: "daily-challenge-reports", targets: ["daily-challenge-reports"]),
  .executable(name: "runner", targets: ["runner"]),
  .executable(name: "server", targets: ["server"]),
  .library(name: "AppSiteAssociationMiddleware", targets: ["AppSiteAssociationMiddleware"]),
  .library(name: "DailyChallengeMiddleware", targets: ["DailyChallengeMiddleware"]),
  .library(name: "DailyChallengeReports", targets: ["DailyChallengeReports"]),
  .library(name: "DatabaseClient", targets: ["DatabaseClient"]),
  .library(name: "DatabaseLive", targets: ["DatabaseLive"]),
  .library(name: "DemoMiddleware", targets: ["DemoMiddleware"]),
  .library(name: "EnvVars", targets: ["EnvVars"]),
  .library(name: "LeaderboardMiddleware", targets: ["LeaderboardMiddleware"]),
  .library(name: "MailgunClient", targets: ["MailgunClient"]),
  .library(name: "MiddlewareHelpers", targets: ["MiddlewareHelpers"]),
  .library(name: "PushMiddleware", targets: ["PushMiddleware"]),
  .library(name: "RunnerTasks", targets: ["RunnerTasks"]),
  .library(name: "ServerBootstrap", targets: ["ServerBootstrap"]),
  .library(name: "ServerConfigMiddleware", targets: ["ServerConfigMiddleware"]),
  .library(name: "ServerTestHelpers", targets: ["ServerTestHelpers"]),
  .library(name: "ShareGameMiddleware", targets: ["ShareGameMiddleware"]),
  .library(name: "SiteMiddleware", targets: ["SiteMiddleware"]),
  .library(name: "SnsClient", targets: ["SnsClient"]),
  .library(name: "SnsClientLive", targets: ["SnsClientLive"]),
  .library(name: "VerifyReceiptMiddleware", targets: ["VerifyReceiptMiddleware"]),
])
package.targets.append(contentsOf: [
  .target(
    name: "AppSiteAssociationMiddleware",
    dependencies: [
      .product(name: "HttpPipeline", package: "swift-web")
    ]
  ),
  .testTarget(
    name: "AppSiteAssociationMiddlewareTests",
    dependencies: [
      "AppSiteAssociationMiddleware",
      "SiteMiddleware",
      .product(name: "HttpPipelineTestSupport", package: "swift-web"),
      .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
    ]
  ),
  .executableTarget(
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
      .product(name: "HttpPipeline", package: "swift-web"),
    ]
  ),
  .testTarget(
    name: "DailyChallengeMiddlewareTests",
    dependencies: [
      "FirstPartyMocks",
      "DailyChallengeMiddleware",
      "SharedModels",
      "SiteMiddleware",
      .product(name: "CustomDump", package: "swift-custom-dump"),
      .product(name: "HttpPipeline", package: "swift-web"),
      .product(name: "HttpPipelineTestSupport", package: "swift-web"),
      .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
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
      "DailyChallengeReports",
      .product(name: "CustomDump", package: "swift-custom-dump"),
    ]
  ),
  .target(
    name: "DatabaseClient",
    dependencies: [
      "Build",
      "ServerTestHelpers",
      "SharedModels",
      "SnsClient",
      .product(name: "Either", package: "swift-prelude"),
      .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
    ]
  ),
  .target(
    name: "DatabaseLive",
    dependencies: [
      "DatabaseClient",
      .product(name: "CasePaths", package: "swift-case-paths"),
      .product(name: "Overture", package: "swift-overture"),
      .product(name: "Prelude", package: "swift-prelude"),
      .product(name: "PostgresKit", package: "postgres-kit"),
    ]
  ),
  .testTarget(
    name: "DatabaseLiveTests",
    dependencies: [
      "DatabaseLive",
      "FirstPartyMocks",
      "TestHelpers",
      .product(name: "CustomDump", package: "swift-custom-dump"),
    ]
  ),
  .target(
    name: "DemoMiddleware",
    dependencies: [
      "DatabaseClient",
      "DictionaryClient",
      "MiddlewareHelpers",
      "SharedModels",
      .product(name: "HttpPipeline", package: "swift-web"),
    ]
  ),
  .testTarget(
    name: "DemoMiddlewareTests",
    dependencies: [
      "DemoMiddleware",
      "SiteMiddleware",
      .product(name: "HttpPipelineTestSupport", package: "swift-web"),
      .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
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
    name: "LeaderboardMiddleware",
    dependencies: [
      "DatabaseClient",
      "DictionaryClient",
      "MiddlewareHelpers",
      "ServerRouter",
      .product(name: "CasePaths", package: "swift-case-paths"),
      .product(name: "HttpPipeline", package: "swift-web"),
    ]
  ),
  .testTarget(
    name: "LeaderboardMiddlewareTests",
    dependencies: [
      "LeaderboardMiddleware",
      "SiteMiddleware",
      .product(name: "CustomDump", package: "swift-custom-dump"),
      .product(name: "HttpPipelineTestSupport", package: "swift-web"),
      .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
    ],
    exclude: ["__Snapshots__"]
  ),
  .target(
    name: "MailgunClient",
    dependencies: [
      "ServerTestHelpers",
      .product(name: "Either", package: "swift-prelude"),
      .product(name: "Tagged", package: "swift-tagged"),
      .product(name: "UrlFormEncoding", package: "swift-web"),
    ]
  ),
  .target(
    name: "MiddlewareHelpers",
    dependencies: [
      "EnvVars",
      .product(name: "HttpPipeline", package: "swift-web"),
    ]
  ),
  .target(
    name: "PushMiddleware",
    dependencies: [
      "Build",
      "DatabaseClient",
      "SharedModels",
      "SnsClient",
      .product(name: "Either", package: "swift-prelude"),
      .product(name: "HttpPipeline", package: "swift-web"),
      .product(name: "Prelude", package: "swift-prelude"),
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
      .product(name: "CustomDump", package: "swift-custom-dump"),
      .product(name: "Either", package: "swift-prelude"),
      .product(name: "HttpPipeline", package: "swift-web"),
      .product(name: "HttpPipelineTestSupport", package: "swift-web"),
      .product(name: "Overture", package: "swift-overture"),
      .product(name: "Prelude", package: "swift-prelude"),
      .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
    ]
  ),
  .executableTarget(
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
      .product(name: "CustomDump", package: "swift-custom-dump"),
    ]
  ),
  .executableTarget(
    name: "server",
    dependencies: [
      "ServerBootstrap",
      "SiteMiddleware",
      .product(name: "HttpPipeline", package: "swift-web"),
    ]
  ),
  .target(
    name: "ServerBootstrap",
    dependencies: [
      "DatabaseLive",
      "DictionarySqliteClient",
      "EnvVars",
      "ServerConfig",
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
      .product(name: "HttpPipeline", package: "swift-web"),
    ]
  ),
  .target(
    name: "ServerTestHelpers",
    dependencies: [
      .product(name: "Either", package: "swift-prelude"),
      .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
    ]
  ),
  .testTarget(
    name: "ServerConfigMiddlewareTests",
    dependencies: [
      "ServerConfigMiddleware",
      "SiteMiddleware",
      .product(name: "Either", package: "swift-prelude"),
      .product(name: "HttpPipeline", package: "swift-web"),
      .product(name: "HttpPipelineTestSupport", package: "swift-web"),
      .product(name: "Prelude", package: "swift-prelude"),
    ]
  ),
  .target(
    name: "ShareGameMiddleware",
    dependencies: [
      "DatabaseClient",
      "EnvVars",
      "MiddlewareHelpers",
      "ServerRouter",
      "SharedModels",
      .product(name: "HttpPipeline", package: "swift-web"),
    ]
  ),
  .testTarget(
    name: "ShareGameMiddlewareTests",
    dependencies: [
      "ShareGameMiddleware",
      "SiteMiddleware",
      "TestHelpers",
      .product(name: "HttpPipelineTestSupport", package: "swift-web"),
      .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
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
      "ServerConfig",
      "ServerConfigMiddleware",
      "SharedModels",
      "ShareGameMiddleware",
      "SnsClient",
      "VerifyReceiptMiddleware",
      .product(name: "HttpPipeline", package: "swift-web"),
      .product(name: "Overture", package: "swift-overture"),
      .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
    ],
    resources: [.process("Resources/")]
  ),
  .testTarget(
    name: "SiteMiddlewareTests",
    dependencies: [
      "FirstPartyMocks",
      "SiteMiddleware",
      "TestHelpers",
      .product(name: "HttpPipelineTestSupport", package: "swift-web"),
      .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
    ],
    exclude: ["__Snapshots__"]
  ),
  .target(
    name: "SnsClient",
    dependencies: [
      "ServerTestHelpers",
      .product(name: "Either", package: "swift-prelude"),
      .product(name: "Tagged", package: "swift-tagged"),
      .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
    ]
  ),
  .testTarget(
    name: "SnsClientTests",
    dependencies: [
      "SnsClient",
      .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
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
    name: "VerifyReceiptMiddleware",
    dependencies: [
      "DatabaseClient",
      "MiddlewareHelpers",
      "ServerRouter",
      "ServerTestHelpers",
      "SharedModels",
      .product(name: "HttpPipeline", package: "swift-web"),
      .product(name: "Overture", package: "swift-overture"),
    ]
  ),
  .testTarget(
    name: "VerifyReceiptMiddlewareTests",
    dependencies: [
      "VerifyReceiptMiddleware",
      "SiteMiddleware",
      .product(name: "CustomDump", package: "swift-custom-dump"),
      .product(name: "HttpPipelineTestSupport", package: "swift-web"),
      .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
    ]
  ),
])
