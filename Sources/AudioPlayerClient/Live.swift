import AVFoundation

extension AudioPlayerClient {
  public static func live(bundles: [Bundle]) -> Self {
    Self(
      load: { sounds in
        .fireAndForget {
          queue.async {
            try? AVAudioSession.sharedInstance().setCategory(.ambient)
            try? AVAudioSession.sharedInstance().setActive(true, options: [])
            for sound in sounds {
              for bundle in bundles {
                guard let url = bundle.url(forResource: sound.name, withExtension: "mp3")
                else { continue }
                files[sound] = AudioPlayer(category: sound.category, url: url)
              }
            }
            try? audioEngine.start()
          }
        }
      },
      loop: { sound in
        .fireAndForget {
          queue.async {
            files[sound]?.play(loop: true)
          }
        }
      },
      play: { sound in
        .fireAndForget {
          queue.async {
            files[sound]?.play()
          }
        }
      },
      secondaryAudioShouldBeSilencedHint: {
        AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
      },
      setGlobalVolumeForMusic: { volume in
        .fireAndForget {
          queue.async {
            musicVolume = volume
          }
        }
      },
      setGlobalVolumeForSoundEffects: { volume in
        .fireAndForget {
          queue.async {
            soundEffectsNode.volume = 0.25 * volume
          }
        }
      },
      setVolume: { sound, volume in
        .fireAndForget {
          queue.async {
            files[sound]?.volume = volume
          }
        }
      },
      stop: { sound in
        .fireAndForget {
          queue.async {
            files[sound]?.stop()
          }
        }
      }
    )
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
