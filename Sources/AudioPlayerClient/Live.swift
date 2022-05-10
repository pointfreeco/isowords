import AVFoundation

extension AudioPlayerClient {
  public static func live(bundles: [Bundle]) -> Self {
    Self(
      load: { sounds in
        await Engine.shared.load(sounds: sounds, bundles: bundles)
      },
      loop: { sound in
        await Engine.shared.files[sound]?.play(loop: true)
      },
      play: { sound in
        await Engine.shared.files[sound]?.play()
      },
      secondaryAudioShouldBeSilencedHint: {
        AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
      },
      setGlobalVolumeForMusic: { volume in
        await Engine.shared.setMusicVolume(volume)
      },
      setGlobalVolumeForSoundEffects: { volume in
        await Engine.shared.setGlobalSoundEffectsVolume(volume)
      },
      setVolume: { sound, volume in
        await Engine.shared.setVolumne(sound: sound, volume: volume)
      },
      stop: { sound in
        await Engine.shared.files[sound]?.stop()
      }
    )
  }
}

private actor Engine: GlobalActor {
  static let shared = Engine()

  var files: [AudioPlayerClient.Sound: AudioPlayer] = [:]
  var musicVolume: Float = 1
  let audioEngine = AVAudioEngine()
  let soundEffectsNode: AVAudioMixerNode

  init() {
    let node = AVAudioMixerNode()
    audioEngine.attach(node)
    audioEngine.connect(node, to: audioEngine.mainMixerNode, format: nil)
    self.soundEffectsNode = node
  }

  func load(sounds: [AudioPlayerClient.Sound], bundles: [Bundle]) {
    let soundsToLoad = sounds.filter { !self.files.keys.contains($0) }

    try? AVAudioSession.sharedInstance().setCategory(.ambient)
    try? AVAudioSession.sharedInstance().setActive(true, options: [])
    for sound in soundsToLoad {
      for bundle in bundles {
        guard let url = bundle.url(forResource: sound.name, withExtension: "mp3")
        else { continue }
        self.files[sound] = AudioPlayer(category: sound.category, url: url)
      }
    }
    guard !self.files.isEmpty else { return }
    try? audioEngine.start()
  }

  func setMusicVolume(_ volume: Float) async {
    self.musicVolume = volume
    for (_, file) in self.files {
      if case .music = file.source {
        await file.setVolume(musicVolume)
      }
    }
  }

  func setGlobalSoundEffectsVolume(_ volume: Float) {
    self.soundEffectsNode.volume = 0.25 * volume
  }

  func setVolumne(sound: AudioPlayerClient.Sound, volume: Float) async {
    await self.files[sound]?.setVolume(volume)
  }
}

private actor AudioPlayer {
  enum Source {
    case music(AVAudioPlayer)
    case soundEffect(AVAudioPlayerNode, AVAudioPCMBuffer)
  }

  let source: Source

  init?(category: AudioPlayerClient.Sound.Category, url: URL) {
    switch category {
    case .music:
      guard let player = try? AVAudioPlayer(contentsOf: url)
      else { return nil }
      self.source = .music(player)

    case .soundEffect:
      guard
        let file = try? AVAudioFile(forReading: url),
        let buffer = AVAudioPCMBuffer(
          pcmFormat: file.processingFormat,
          frameCapacity: AVAudioFrameCount(file.length)
        ),
        (try? file.read(into: buffer)) != nil
      else { return nil }
      let node = AVAudioPlayerNode()
      Engine.shared.audioEngine.attach(node)
      Engine.shared.audioEngine.connect(node, to: Engine.shared.soundEffectsNode, format: nil)
      self.source = .soundEffect(node, buffer)
    }
  }

  func play(loop: Bool = false) async {
    switch self.source {
    case let .music(player):
      player.currentTime = 0
      player.numberOfLoops = loop ? -1 : 0
      player.volume = await Engine.shared.musicVolume
      player.play()

    case let .soundEffect(node, buffer):
      if !Engine.shared.audioEngine.isRunning {
        guard (try? Engine.shared.audioEngine.start()) != nil else { return }
      }

      node.stop()
      node.scheduleBuffer(
        buffer,
        at: nil,
        options: loop ? .loops : [],
        completionCallbackType: .dataPlayedBack,
        completionHandler: nil
      )
      node.play(at: nil)
    }
  }

  func setVolume(_ volume: Float) {
    switch self.source {
    case let .music(player):
      player.volume = volume

    case let .soundEffect(node, _):
      node.volume = volume
    }
  }

  func stop() {
    switch self.source {
    case let .music(player):
      player.setVolume(0, fadeDuration: 2.5)
      player.stop()

    case let .soundEffect(node, _):
      node.stop()
    }
  }
}
