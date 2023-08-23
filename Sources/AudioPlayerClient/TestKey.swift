import Dependencies
import XCTestDynamicOverlay

extension DependencyValues {
  public var audioPlayer: AudioPlayerClient {
    get { self[AudioPlayerClient.self] }
    set { self[AudioPlayerClient.self] = newValue }
  }
}

extension AudioPlayerClient: TestDependencyKey {
  public static let previewValue = Self.noop

  public static let testValue = Self(
    load: unimplemented("\(Self.self).load"),
    loop: unimplemented("\(Self.self).loop"),
    play: unimplemented("\(Self.self).play"),
    secondaryAudioShouldBeSilencedHint: unimplemented(
      "\(Self.self).secondaryAudioShouldBeSilencedHint", placeholder: false
    ),
    setGlobalVolumeForMusic: unimplemented("\(Self.self).setGlobalVolumeForMusic"),
    setGlobalVolumeForSoundEffects: unimplemented(
      "\(Self.self).setGlobalVolumeForSoundEffects"
    ),
    setVolume: unimplemented("\(Self.self).setVolume"),
    stop: unimplemented("\(Self.self).stop")
  )
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
