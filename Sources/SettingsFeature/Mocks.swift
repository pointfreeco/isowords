#if DEBUG
  extension SettingsState {
    public static let everythingOff = Self(
      userSettings: .init(
        enableGyroMotion: false,
        enableHaptics: false
      )
    )
  }
#endif
