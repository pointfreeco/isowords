import ApiClient
import AudioPlayerClient
import Build
import ComposableArchitecture
import ComposableGameCenter
import ComposableStoreKit
import ComposableUserNotifications
import DeviceId
import DictionaryClient
import FeedbackGeneratorClient
import FileClient
import LocalDatabaseClient
import LowPowerModeClient
import RemoteNotificationsClient
import ServerConfigClient
import SharedModels
import UIApplicationClient
import UIKit
import UserDefaultsClient
import XCTestDynamicOverlay

public struct AppEnvironment {
  public var apiClient: ApiClient
  public var applicationClient: UIApplicationClient
  public var audioPlayer: AudioPlayerClient
  public var backgroundQueue: AnySchedulerOf<DispatchQueue>
  public var build: Build
  public var database: LocalDatabaseClient
  public var deviceId: DeviceIdentifier
  public var dictionary: DictionaryClient
  public var feedbackGenerator: FeedbackGeneratorClient
  public var fileClient: FileClient
  public var gameCenter: GameCenterClient
  public var lowPowerMode: LowPowerModeClient
  public var mainQueue: AnySchedulerOf<DispatchQueue>
  public var mainRunLoop: AnySchedulerOf<RunLoop>
  public var remoteNotifications: RemoteNotificationsClient
  public var serverConfig: ServerConfigClient
  public var setUserInterfaceStyle: @Sendable (UIUserInterfaceStyle) async -> Void
  public var storeKit: StoreKitClient
  public var timeZone: () -> TimeZone
  public var userDefaults: UserDefaultsClient
  public var userNotifications: UserNotificationClient

  public init(
    apiClient: ApiClient,
    applicationClient: UIApplicationClient,
    audioPlayer: AudioPlayerClient,
    backgroundQueue: AnySchedulerOf<DispatchQueue>,
    build: Build,
    database: LocalDatabaseClient,
    deviceId: DeviceIdentifier,
    dictionary: DictionaryClient,
    feedbackGenerator: FeedbackGeneratorClient,
    fileClient: FileClient,
    gameCenter: GameCenterClient,
    lowPowerMode: LowPowerModeClient,
    mainQueue: AnySchedulerOf<DispatchQueue>,
    mainRunLoop: AnySchedulerOf<RunLoop>,
    remoteNotifications: RemoteNotificationsClient,
    serverConfig: ServerConfigClient,
    setUserInterfaceStyle: @escaping @Sendable (UIUserInterfaceStyle) async -> Void,
    storeKit: StoreKitClient,
    timeZone: @escaping () -> TimeZone,
    userDefaults: UserDefaultsClient,
    userNotifications: UserNotificationClient
  ) {
    self.apiClient = apiClient
    self.audioPlayer = audioPlayer
    self.applicationClient = applicationClient
    self.backgroundQueue = backgroundQueue
    self.build = build
    self.database = database
    self.deviceId = deviceId
    self.dictionary = dictionary
    self.feedbackGenerator = feedbackGenerator
    self.fileClient = fileClient
    self.gameCenter = gameCenter
    self.lowPowerMode = lowPowerMode
    self.mainQueue = mainQueue
    self.mainRunLoop = mainRunLoop
    self.remoteNotifications = remoteNotifications
    self.serverConfig = serverConfig
    self.setUserInterfaceStyle = setUserInterfaceStyle
    self.storeKit = storeKit
    self.timeZone = timeZone
    self.userDefaults = userDefaults
    self.userNotifications = userNotifications
  }

  #if DEBUG
    public static let unimplemented = Self(
      apiClient: .unimplemented,
      applicationClient: .unimplemented,
      audioPlayer: .unimplemented,
      backgroundQueue: .unimplemented("backgroundQueue"),
      build: .unimplemented,
      database: .unimplemented,
      deviceId: .unimplemented,
      dictionary: .unimplemented,
      feedbackGenerator: .unimplemented,
      fileClient: .unimplemented,
      gameCenter: .unimplemented,
      lowPowerMode: .unimplemented,
      mainQueue: .unimplemented("mainQueue"),
      mainRunLoop: .unimplemented("mainRunLoop"),
      remoteNotifications: .unimplemented,
      serverConfig: .unimplemented,
      setUserInterfaceStyle: XCTUnimplemented("\(Self.self).setUserInterfaceStyle"),
      storeKit: .unimplemented,
      timeZone: XCTUnimplemented("\(Self.self).timeZone"),
      userDefaults: .unimplemented,
      userNotifications: .unimplemented
    )

    public static let noop = Self(
      apiClient: .noop,
      applicationClient: .noop,
      audioPlayer: .noop,
      backgroundQueue: .immediate,
      build: .noop,
      database: .noop,
      deviceId: .noop,
      dictionary: .everyString,
      feedbackGenerator: .noop,
      fileClient: .noop,
      gameCenter: .noop,
      lowPowerMode: .false,
      mainQueue: .immediate,
      mainRunLoop: .immediate,
      remoteNotifications: .noop,
      serverConfig: .noop,
      setUserInterfaceStyle: { _ in },
      storeKit: .noop,
      timeZone: { .autoupdatingCurrent },
      userDefaults: .noop,
      userNotifications: .noop
    )
  #endif
}
