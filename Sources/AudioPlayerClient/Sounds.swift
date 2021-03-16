import Foundation

extension AudioPlayerClient.Sound {
  public static let allCases =
    allMusic
    + allValidWords
    + allNotes
    + allSubmits
    + allUngrouped

  public static let allMusic = [
    gameOverMusicLoop,
    onboardingBgMusic,
    timedGameBgLoop1,
    timedGameBgLoop2,
    unlimitedGameBgLoop1,
    unlimitedGameBgLoop2,
  ]

  public static let allNotes = (1...4).flatMap { level in
    Note.allCases.map { note in
      Self.note(note, level: level)
    }
  }

  public static let allSubmits = (1...2).flatMap { level in
    Note.allCases.map { note in
      Self.submit(note, level: level)
    }
  }

  public static let allValidWords = (1...7).flatMap { level in
    Note.allCases.map { note in
      Self.validWord(level: level)
    }
  }

  public static let allUngrouped = [
    cubeDeselect,
    cubeRemove,
    cubeShake,
    highScoreCelebration,
    invalidWord,
    timed10SecWarning,
    timedCountdownTone,
    transitionIn,
    uiSfxActionPassive,
    uiSfxActionSecondary,
    uiSfxActionDestructive,
    uiSfxEmojiClose,
    uiSfxEmojiOpen,
    uiSfxEmojiSend,
    uiSfxHi,
    uiSfxPop,
    uiSfxReciveNotification,
    uiSfxReverse,
    uiSfxSendNotification,
    uiSfxSuccessAction,
    uiSfxTap,
  ]

  public static let cubeDeselect = Self("Cube-Deselect")
  public static let cubeRemove = Self("Cube-Remove")
  public static let cubeShake = Self("Cube-Shake")
  public static let gameOverMusicLoop = Self("Game-Over-Music-Loop", .music)
  public static let highScoreCelebration = Self("High-Score-Celebration")
  public static let invalidWord = Self("Invalid-Word")
  public static let onboardingBgMusic = Self("Onboarding-BG-Music", .music)
  public static let timed10SecWarning = Self("Timed-10-Sec-Warning")
  public static let timedCountdownTone = Self("Timed-Countdown-Tone")
  public static let timedGameBgLoop1 = Self("Timed-Game-BG-Loop-1", .music)
  public static let timedGameBgLoop2 = Self("Timed-Game-BG-Loop-2", .music)
  public static let transitionIn = Self("Transition-In")
  public static let unlimitedGameBgLoop1 = Self("Unlimited-Game-BG-Loop-1", .music)
  public static let unlimitedGameBgLoop2 = Self("Unlimited-Game-BG-Loop-2", .music)
  public static let uiSfxActionDestructive = Self("UI-SFX-Action-Destructive")
  public static let uiSfxActionPassive = Self("UI-SFX-Action-Passive")
  public static let uiSfxActionSecondary = Self("UI-SFX-Action-Secondary")
  public static let uiSfxEmojiClose = Self("UI-SFX-Emoji-Close")
  public static let uiSfxEmojiOpen = Self("UI-SFX-Emoji-Open")
  public static let uiSfxEmojiSend = Self("UI-SFX-Emoji-Send")
  public static let uiSfxHi = Self("UI-SFX-HI")
  public static let uiSfxPop = Self("UI-SFX-Pop")
  public static let uiSfxReciveNotification = Self("UI-SFX-Receive-Notification")
  public static let uiSfxReverse = Self("UI-SFX-Reverse")
  public static let uiSfxSendNotification = Self("UI-SFX-Send-Notification")
  public static let uiSfxSuccessAction = Self("UI-SFX-Success-Action")
  public static let uiSfxTap = Self("UI-SFX-Tap")

  public static func note(_ note: Note, level: Int) -> Self {
    Self("Cube-Note-\(note.rawValue)\(level)")
  }

  public static func submit(_ note: Note, level: Int) -> Self {
    Self("Cube-Submit-\(note.rawValue)-Root-\(level)")
  }

  public static func validWord(level: Int) -> Self {
    Self("Valid-Word-\(level)")
  }

  public enum Note: String, CaseIterable {
    case C, D, E, F, G, A, B
  }

  private init(_ name: String, _ category: Category = .soundEffect) {
    self.init(
      category: category,
      name: name
    )
  }
}
