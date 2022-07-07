import AVFoundation
import Dependencies

extension AudioPlayerClient {
  public static func live(bundles: [Bundle]) -> Self {
    let actor = AudioActor(bundles: .init(wrappedValue: bundles))
    return Self(
      load: { sounds in .fireAndForget { Task { try! await actor.load(sounds: sounds) } } },
      loadAsync: { try? await actor.load(sounds: $0) },
      loop: { sound in .fireAndForget { Task { try! await actor.play(sound: sound, loop: true) } } },
      loopAsync: { try? await actor.play(sound: $0, loop: true) },
      play: { sound in .fireAndForget { Task { try! await actor.play(sound: sound) } } },
      playAsync: { try? await actor.play(sound: $0) },
      secondaryAudioShouldBeSilencedHint: {
        AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
      },
      secondaryAudioShouldBeSilencedHintAsync: {
        AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
      },
      setGlobalVolumeForMusic: { volume in
        .fireAndForget { Task { await actor.setMusicVolume(to: volume) } }
      },
      setGlobalVolumeForMusicAsync: { await actor.setMusicVolume(to: $0) },
      setGlobalVolumeForSoundEffects: { volume in
        .fireAndForget { Task { await actor.setSoundEffectsVolume(to: volume) } }
      },
      setGlobalVolumeForSoundEffectsAsync: { await actor.setSoundEffectsVolume(to: $0) },
      setVolume: { sound, volume in
        .fireAndForget { Task { try! await actor.setVolume(of: sound, to: volume) } }
      },
      setVolumeAsync: { try? await actor.setVolume(of: $0, to: $1) },
      stop: { sound in .fireAndForget { Task { try! await actor.stop(sound: sound) } } },
      stopAsync: { try? await actor.stop(sound: $0) }
    )
  }

  private actor AudioActor {
    enum Failure: Error {
      case bufferInitializationFailed
      case soundNotLoaded(AudioPlayerClient.Sound)
      case soundsNotLoaded([AudioPlayerClient.Sound: Error])
    }

    enum Player {
      case music(AVAudioPlayer)
      case soundEffect(AVAudioPlayerNode, AVAudioPCMBuffer)
    }

    let audioEngine: AVAudioEngine
    let bundles: [Bundle]
    var players: [Sound: Player] = [:]
    let soundEffectsNode: AVAudioMixerNode

    init(bundles: UncheckedSendable<[Bundle]>) {
      let audioEngine = AVAudioEngine()
      let soundEffectsNode = AVAudioMixerNode()
      audioEngine.attach(soundEffectsNode)
      audioEngine.connect(soundEffectsNode, to: audioEngine.mainMixerNode, format: nil)
      self.audioEngine = audioEngine
      self.bundles = bundles.wrappedValue
      self.soundEffectsNode = soundEffectsNode
    }

    func load(sounds: [Sound]) throws {
      let sounds = sounds.filter { !self.players.keys.contains($0) }
      try AVAudioSession.sharedInstance().setCategory(.ambient)
      try AVAudioSession.sharedInstance().setActive(true, options: [])
      var errors: [Sound: Error] = [:]
      for sound in sounds {
        for bundle in self.bundles {
          do {
            guard let url = bundle.url(forResource: sound.name, withExtension: "mp3")
            else { continue }
            switch sound.category {
            case .music:
              self.players[sound] = try .music(AVAudioPlayer(contentsOf: url))

            case .soundEffect:
              let file = try AVAudioFile(forReading: url)
              guard
                let buffer = AVAudioPCMBuffer(
                  pcmFormat: file.processingFormat,
                  frameCapacity: AVAudioFrameCount(file.length)
                )
              else { throw Failure.bufferInitializationFailed }
              try file.read(into: buffer)
              let node = AVAudioPlayerNode()
              audioEngine.attach(node)
              audioEngine.connect(node, to: soundEffectsNode, format: nil)
              self.players[sound] = .soundEffect(node, buffer)
            }
          } catch {
            errors[sound] = error
          }
        }
      }
      guard errors.isEmpty else { throw Failure.soundsNotLoaded(errors) }
    }

    func play(sound: Sound, loop: Bool = false) throws {
      guard let player = self.players[sound] else { throw Failure.soundNotLoaded(sound) }

      switch player {
      case let .music(player):
        player.numberOfLoops = loop ? -1 : 0
        player.play(atTime: 0)

      case let .soundEffect(node, buffer):
        if !self.audioEngine.isRunning {
          try audioEngine.start()
        }

        node.stop()  // TODO: Is this needed?
        node.scheduleBuffer(
          buffer,
          at: nil,
          options: loop ? .loops : [],
          completionCallbackType: .dataPlayedBack,
          completionHandler: nil
        )
        node.play()  // TODO: Is this needed?
      }
    }

    func stop(sound: Sound) throws {
      guard let player = self.players[sound] else { throw Failure.soundNotLoaded(sound) }

      switch player {
      case let .music(player):
        player.setVolume(0, fadeDuration: 2.5)
        Task {
          try await Task.sleep(nanoseconds: 2_500 * NSEC_PER_MSEC)
          player.stop()
        }

      case let .soundEffect(node, _):
        node.stop()
      }
    }

    func setVolume(of sound: Sound, to volume: Float) throws {
      guard let player = self.players[sound] else { throw Failure.soundNotLoaded(sound) }

      switch player {
      case let .music(player):
        player.volume = volume

      case let .soundEffect(node, _):
        node.volume = volume
      }
    }

    func setMusicVolume(to volume: Float) {
      for (sound, _) in self.players where sound.category == .music {
        try? self.setVolume(of: sound, to: volume)
      }
    }

    func setSoundEffectsVolume(to volume: Float) {
      self.soundEffectsNode.volume = 0.25 * volume
    }
  }
}

private var files: [AudioPlayerClient.Sound: AudioPlayer] = [:]

private class AudioPlayer {
  enum Source {
    case music(AVAudioPlayer)
    case soundEffect(AVAudioPlayerNode, AVAudioPCMBuffer)
  }

  let source: Source
  var volume: Float = 1 {
    didSet {
      self.setVolume(self.volume)
    }
  }

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
      audioEngine.attach(node)
      audioEngine.connect(node, to: soundEffectsNode, format: nil)
      self.source = .soundEffect(node, buffer)
    }
  }

  func play(loop: Bool = false) {
    switch self.source {
    case let .music(player):
      player.currentTime = 0
      player.numberOfLoops = loop ? -1 : 0
      player.volume = musicVolume
      player.play()

    case let .soundEffect(node, buffer):
      if !audioEngine.isRunning {
        guard (try? audioEngine.start()) != nil else { return }
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

  private func setVolume(_ volume: Float) {
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
      queue.asyncAfter(deadline: .now() + 2.5) {
        player.stop()
      }

    case let .soundEffect(node, _):
      node.stop()
    }
  }
}

let audioEngine = AVAudioEngine()
let soundEffectsNode: AVAudioMixerNode = {
  let node = AVAudioMixerNode()
  audioEngine.attach(node)
  audioEngine.connect(node, to: audioEngine.mainMixerNode, format: nil)
  return node
}()
private var musicVolume: Float = 1 {
  didSet {
    files.forEach { _, file in
      if case .music = file.source {
        file.volume = musicVolume
      }
    }
  }
}
private let queue = DispatchQueue(label: "Audio Dispatch Queue")
