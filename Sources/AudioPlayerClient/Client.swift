import ComposableArchitecture

public struct AudioPlayerClient {
  @available(*, deprecated) public var load: ([Sound]) -> Effect<Never, Never>
  public var loadAsync: @Sendable ([Sound]) async -> Void
  @available(*, deprecated) public var loop: (Sound) -> Effect<Never, Never>
  public var loopAsync: @Sendable (Sound) async -> Void
  @available(*, deprecated) public var play: (Sound) -> Effect<Never, Never>
  public var playAsync: @Sendable (Sound) async -> Void
  @available(*, deprecated) public var secondaryAudioShouldBeSilencedHint: () -> Bool
  public var secondaryAudioShouldBeSilencedHintAsync: @Sendable () async -> Bool
  @available(*, deprecated) public var setGlobalVolumeForMusic: (Float) -> Effect<Never, Never>
  public var setGlobalVolumeForMusicAsync: @Sendable (Float) async -> Void
  @available(*, deprecated) public var setGlobalVolumeForSoundEffects: (Float) -> Effect<Never, Never>
  public var setGlobalVolumeForSoundEffectsAsync: @Sendable (Float) async -> Void
  @available(*, deprecated) public var setVolume: (Sound, Float) -> Effect<Never, Never>
  public var setVolumeAsync: @Sendable (Sound, Float) async ->Void
  @available(*, deprecated) public var stop: (Sound) -> Effect<Never, Never>
  public var stopAsync: @Sendable (Sound) async -> Void

  public struct Sound: Hashable {
    public let category: Category
    public let name: String

    public init(category: Category, name: String) {
      self.category = category
      self.name = name
    }

    public enum Category: Hashable {
      case music
      case soundEffect
    }
  }

  public func filteredSounds(doNotInclude doNotIncludeSounds: [AudioPlayerClient.Sound]) -> Self {
    var client = self
    client.play = { sound in
      guard doNotIncludeSounds.contains(sound)
      else { return self.play(sound) }
      return .none
    }
    return client
  }
}

extension AudioPlayerClient {
  public static let noop = Self(
    load: { _ in .none },
    loadAsync: { _ in },
    loop: { _ in .none },
    loopAsync: { _ in },
    play: { _ in .none },
    playAsync: { _ in },
    secondaryAudioShouldBeSilencedHint: { false },
    secondaryAudioShouldBeSilencedHintAsync: { false },
    setGlobalVolumeForMusic: { _ in .none },
    setGlobalVolumeForMusicAsync: { _ in },
    setGlobalVolumeForSoundEffects: { _ in .none },
    setGlobalVolumeForSoundEffectsAsync: { _ in },
    setVolume: { _, _ in .none },
    setVolumeAsync: { _, _ in },
    stop: { _ in .none },
    stopAsync: { _ in }
  )
}

#if DEBUG
  import XCTestDynamicOverlay

  extension AudioPlayerClient {
    public static let failing = Self(
      load: { _ in .failing("\(Self.self).load is unimplemented") },
      loadAsync: XCTUnimplemented("\(Self.self).loadAsync"),
      loop: { _ in .failing("\(Self.self).loop is unimplemented") },
      loopAsync: XCTUnimplemented("\(Self.self).loopAsync"),
      play: { _ in .failing("\(Self.self).play is unimplemented") },
      playAsync: XCTUnimplemented("\(Self.self).playAsync"),
      secondaryAudioShouldBeSilencedHint: XCTUnimplemented(
        "\(Self.self).secondaryAudioShouldBeSilencedHint", placeholder: false
      ),
      secondaryAudioShouldBeSilencedHintAsync: XCTUnimplemented(
        "\(Self.self).secondaryAudioShouldBeSilencedHintAsync", placeholder: false
      ),
      setGlobalVolumeForMusic: { _ in
        .failing("\(Self.self).setGlobalVolumeForMusic is unimplemented")
      },
      setGlobalVolumeForMusicAsync: XCTUnimplemented("\(Self.self).setGlobalVolumeForMusicAsync"),
      setGlobalVolumeForSoundEffects: { _ in
        .failing("\(Self.self).setGlobalVolumeForSoundEffects is unimplemented")
      },
      setGlobalVolumeForSoundEffectsAsync: XCTUnimplemented(
        "\(Self.self).setGlobalVolumeForSoundEffectsAsync"
      ),
      setVolume: { _, _ in .failing("\(Self.self).setVolume is unimplemented") },
      setVolumeAsync: XCTUnimplemented("\(Self.self).setVolumeAsync"),
      stop: { _ in .failing("\(Self.self).stop is unimplemented") },
      stopAsync: XCTUnimplemented("\(Self.self).stopAsync")
    )
  }
#endif
