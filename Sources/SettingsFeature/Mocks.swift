#if DEBUG
  extension Settings.State {
    public static let everythingOff = Self(
      userSettings: .init(
        enableGyroMotion: false,
        enableHaptics: false
      )
    )
  }
#endif
