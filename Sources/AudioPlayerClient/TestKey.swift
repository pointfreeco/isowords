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
    load: XCTUnimplemented("\(Self.self).load"),
    loop: XCTUnimplemented("\(Self.self).loop"),
    play: XCTUnimplemented("\(Self.self).play"),
    secondaryAudioShouldBeSilencedHint: XCTUnimplemented(
      "\(Self.self).secondaryAudioShouldBeSilencedHint", placeholder: false
    ),
    setGlobalVolumeForMusic: XCTUnimplemented("\(Self.self).setGlobalVolumeForMusic"),
    setGlobalVolumeForSoundEffects: XCTUnimplemented(
      "\(Self.self).setGlobalVolumeForSoundEffects"
    ),
    setVolume: XCTUnimplemented("\(Self.self).setVolume"),
    stop: XCTUnimplemented("\(Self.self).stop")
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
