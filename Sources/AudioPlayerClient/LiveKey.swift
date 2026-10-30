import AVFoundation
import ConcurrencyExtras

extension AudioPlayerClient {
  public static func live(bundles: [Bundle]) -> Self {
    let actor = AudioActor(bundles: .init(wrappedValue: bundles))
    return Self(
      load: { try? await actor.load(sounds: $0) },
      loop: { try? await actor.play(sound: $0, loop: true) },
      play: { try? await actor.play(sound: $0) },
      secondaryAudioShouldBeSilencedHint: {
        AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
      },
      setGlobalVolumeForMusic: { await actor.setMusicVolume(to: $0) },
      setGlobalVolumeForSoundEffects: { await actor.setSoundEffectsVolume(to: $0) },
      setVolume: { try? await actor.setVolume(of: $0, to: $1) },
      stop: { try? await actor.stop(sound: $0) }
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
    var musicVolume: Float = 1.0
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
      let sounds = sounds.filter { !players.keys.contains($0) }
      try AVAudioSession.sharedInstance().setCategory(.ambient)
      try AVAudioSession.sharedInstance().setActive(true, options: [])
      var errors: [Sound: Error] = [:]
      for sound in sounds {
        for bundle in bundles {
          do {
            guard let url = bundle.url(forResource: sound.name, withExtension: "mp3")
            else { continue }
            switch sound.category {
            case .music:
              players[sound] = try .music(AVAudioPlayer(contentsOf: url))

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
              players[sound] = .soundEffect(node, buffer)
            }
          } catch {
            errors[sound] = error
          }
        }
      }
      guard errors.isEmpty else { throw Failure.soundsNotLoaded(errors) }
    }

    func play(sound: Sound, loop: Bool = false) throws {
      guard let player = players[sound] else { throw Failure.soundNotLoaded(sound) }

      switch player {
      case let .music(player):
        player.currentTime = 0
        player.numberOfLoops = loop ? -1 : 0
        player.volume = musicVolume
        player.play()

      case let .soundEffect(node, buffer):
        if !audioEngine.isRunning {
          try audioEngine.start()
        }

        node.scheduleBuffer(
          buffer,
          at: nil,
          options: loop ? .loops : [],
          completionCallbackType: .dataPlayedBack,
          completionHandler: nil
        )
        node.play()
      }
    }

    func stop(sound: Sound) throws {
      guard let player = players[sound] else { throw Failure.soundNotLoaded(sound) }

      switch player {
      case let .music(player):
        player.setVolume(0, fadeDuration: 2.5)
        _ = Task {
          try await Task.sleep(for: .seconds(2.5))
          player.stop()
        }

      case let .soundEffect(node, _):
        node.stop()
      }
    }

    func setVolume(of sound: Sound, to volume: Float) throws {
      guard let player = players[sound] else { throw Failure.soundNotLoaded(sound) }

      switch player {
      case let .music(player):
        player.volume = volume

      case let .soundEffect(node, _):
        node.volume = volume
      }
    }

    func setMusicVolume(to volume: Float) {
      musicVolume = volume
      for (sound, _) in players where sound.category == .music {
        try? setVolume(of: sound, to: volume)
      }
    }

    func setSoundEffectsVolume(to volume: Float) {
      soundEffectsNode.volume = 0.25 * volume
    }
  }
}
