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
  public var setUserInterfaceStyle: (UIUserInterfaceStyle) -> Effect<Never, Never>
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
    setUserInterfaceStyle: @escaping (UIUserInterfaceStyle) -> Effect<Never, Never>,
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
    public static let failing = Self(
      apiClient: .failing,
      applicationClient: .failing,
      audioPlayer: .failing,
      backgroundQueue: .failing("backgroundQueue"),
      build: .failing,
      database: .failing,
      deviceId: .failing,
      dictionary: .failing,
      feedbackGenerator: .failing,
      fileClient: .failing,
      gameCenter: .failing,
      lowPowerMode: .failing,
      mainQueue: .failing("mainQueue"),
      mainRunLoop: .failing("mainRunLoop"),
      remoteNotifications: .failing,
      serverConfig: .failing,
      setUserInterfaceStyle: { _ in
        .failing("\(Self.self).setUserInterfaceStyle is unimplemented")
      },
      storeKit: .failing,
      timeZone: {
        XCTFail("\(Self.self).timeZone is unimplemented")
        return TimeZone(secondsFromGMT: 0)!
      },
      userDefaults: .failing,
      userNotifications: .failing
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
      setUserInterfaceStyle: { _ in .none },
      storeKit: .noop,
      timeZone: { .autoupdatingCurrent },
      userDefaults: .noop,
      userNotifications: .noop
    )
  #endif
}
