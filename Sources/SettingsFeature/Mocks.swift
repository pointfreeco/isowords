#if DEBUG
  import Dependencies

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
