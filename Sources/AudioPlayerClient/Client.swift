import ComposableArchitecture

public struct AudioPlayerClient {
  public var load: @Sendable ([Sound]) async -> Void
  public var loop: @Sendable (Sound) async -> Void
  public var play: @Sendable (Sound) async -> Void
  public var secondaryAudioShouldBeSilencedHint: @Sendable () async -> Bool
  public var setGlobalVolumeForMusic: @Sendable (Float) async -> Void
  public var setGlobalVolumeForSoundEffects: @Sendable (Float) async -> Void
  public var setVolume: @Sendable (Sound, Float) async ->Void
  public var stop: @Sendable (Sound) async -> Void

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
      else { return await self.play(sound) }
    }
    return client
  }
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

#if DEBUG
  import XCTestDynamicOverlay

  extension AudioPlayerClient {
    public static let failing = Self(
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
#endif
