import ComposableArchitecture

public struct AudioPlayerClient {
  public var load: ([Sound]) -> Effect<Never, Never>
  public var loop: (Sound) -> Effect<Never, Never>
  public var play: (Sound) -> Effect<Never, Never>
  public var secondaryAudioShouldBeSilencedHint: () -> Bool
  public var setGlobalVolumeForMusic: (Float) -> Effect<Never, Never>
  public var setGlobalVolumeForSoundEffects: (Float) -> Effect<Never, Never>
  public var setVolume: (Sound, Float) -> Effect<Never, Never>
  public var stop: (Sound) -> Effect<Never, Never>

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
    loop: { _ in .none },
    play: { _ in .none },
    secondaryAudioShouldBeSilencedHint: { false },
    setGlobalVolumeForMusic: { _ in .none },
    setGlobalVolumeForSoundEffects: { _ in .none },
    setVolume: { _, _ in .none },
    stop: { _ in .none }
  )
}

#if DEBUG
  import XCTestDynamicOverlay

  extension AudioPlayerClient {
    public static let failing = Self(
      load: { _ in .failing("\(Self.self).load is unimplemented") },
      loop: { _ in .failing("\(Self.self).loop is unimplemented") },
      play: { _ in .failing("\(Self.self).play is unimplemented") },
      secondaryAudioShouldBeSilencedHint: {
        XCTFail("\(Self.self).secondaryAudioShouldBeSilencedHint is unimplemented")
        return false
      },
      setGlobalVolumeForMusic: { _ in
        .failing("\(Self.self).setGlobalVolumeForMusic is unimplemented")
      },
      setGlobalVolumeForSoundEffects: { _ in
        .failing("\(Self.self).setGlobalVolumeForSoundEffects is unimplemented")
      },
      setVolume: { _, _ in .failing("\(Self.self).setVolume is unimplemented") },
      stop: { _ in .failing("\(Self.self).stop is unimplemented") }
    )
  }
#endif
