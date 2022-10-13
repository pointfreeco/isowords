public struct AudioPlayerClient {
  public var load: @Sendable ([Sound]) async -> Void
  public var loop: @Sendable (Sound) async -> Void
  public var play: @Sendable (Sound) async -> Void
  public var secondaryAudioShouldBeSilencedHint: @Sendable () async -> Bool
  public var setGlobalVolumeForMusic: @Sendable (Float) async -> Void
  public var setGlobalVolumeForSoundEffects: @Sendable (Float) async -> Void
  public var setVolume: @Sendable (Sound, Float) async -> Void
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
