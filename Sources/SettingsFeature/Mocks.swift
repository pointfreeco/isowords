#if DEBUG
  import Dependencies
  import UserSettingsClient

  extension Settings.State {
    public static let everythingOff = withDependencies {
      $0.userSettings = .mock(
        initialUserSettings: UserSettings(
          enableGyroMotion: false,
          enableHaptics: false
        )
      )
    } operation: {
      Self()
    }
  }
#endif
