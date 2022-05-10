import ComposableArchitecture

public struct AudioPlayerClient {
  public var load: ([Sound]) async -> Void
  public var loop: (Sound) async -> Void
  public var play: (Sound) async -> Void
  public var secondaryAudioShouldBeSilencedHint: () -> Bool
  public var setGlobalVolumeForMusic: (Float) async -> Void
  public var setGlobalVolumeForSoundEffects: (Float) async -> Void
  public var setVolume: (Sound, Float) async -> Void
  public var stop: (Sound) async -> Void

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
      return
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
      load: { _ in XCTFail("\(Self.self).load is unimplemented") },
      loop: { _ in XCTFail("\(Self.self).loop is unimplemented") },
      play: { _ in XCTFail("\(Self.self).play is unimplemented") },
      secondaryAudioShouldBeSilencedHint: {
        XCTFail("\(Self.self).secondaryAudioShouldBeSilencedHint is unimplemented")
        return false
      },
      setGlobalVolumeForMusic: { _ in
        XCTFail("\(Self.self).setGlobalVolumeForMusic is unimplemented")
      },
      setGlobalVolumeForSoundEffects: { _ in
        XCTFail("\(Self.self).setGlobalVolumeForSoundEffects is unimplemented")
      },
      setVolume: { _, _ in XCTFail("\(Self.self).setVolume is unimplemented") },
      stop: { _ in XCTFail("\(Self.self).stop is unimplemented") }
    )
  }
#endif
