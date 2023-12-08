import Dependencies

extension DependencyValues {
  public var audioPlayer: AudioPlayerClient {
    get { self[AudioPlayerClient.self] }
    set { self[AudioPlayerClient.self] = newValue }
  }
}

extension AudioPlayerClient: TestDependencyKey {
  public static let previewValue = Self.noop
  public static let testValue = Self()
}

extension AudioPlayerClient {
  public static let noop = Self(
    load: { _ in },
    loop: { _ in },
    play: { _ in },
    secondaryAudioShouldBeSilencedHint: { false },
    setGlobalVolumeForMusic: { _ in },
    setGlobalVolumeForSoundEffects: { _ in },
    setVolume: { _, _ in },
    stop: { _ in }
  )
}
