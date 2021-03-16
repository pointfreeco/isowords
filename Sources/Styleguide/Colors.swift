import SwiftUI

extension Color {
  public static let adaptiveWhite = Self {
    $0.userInterfaceStyle == .dark ? .isowordsBlack : .white
  }
  public static let adaptiveBlack = Self {
    $0.userInterfaceStyle == .dark ? .white : .isowordsBlack
  }

  public static let isowordsBlack = hex(0x121212)
  public static let isowordsOrange = hex(0xEAA980)
  public static let isowordsRed = hex(0xE1685C)
  public static let isowordsYellow = hex(0xF3E7A2)

  public static let dailyChallenge = isowordsYellow
  public static let multiplayer = isowordsRed
  public static let solo = isowordsOrange
}

extension UIColor {
  public static let cubeFaceDefaultColor = UIColor.white
  public static let cubeFaceUsedColor = UIColor.hex(0xcccccc)
  public static let cubeFaceSelectableColor = UIColor.hex(0xf7ddcc)
  public static let cubeFaceSelectedColor = UIColor(cgColor: Color.isowordsOrange.cgColor!)
  public static let cubeFaceCriticalColor = UIColor.hex(0xEDA49D)
  public static let cubeRemovedColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0)
}

public let letterColors = [
  "A"..<"H": [UIColor.hex(0xF3E7A2), .hex(0xEDBB8A), .hex(0xE79474), .hex(0xE1685C)],
  "H"..<"O": [UIColor.hex(0xF3E7A2), .hex(0xEDBB8A), .hex(0xE79474), .hex(0xE1685C)],
  "O"..<"V": [UIColor.hex(0xF3E7A2), .hex(0xEDBB8A), .hex(0xE79474), .hex(0xE1685C)],
  "V"..<"ZZZ": [UIColor.hex(0xF3E7A2), .hex(0xEDBB8A), .hex(0xE79474), .hex(0xE1685C)],
]

public func colors(for word: String) -> [Color] {
  letterColors
    .first(where: { range, _ in range.contains(word) })?
    .value
    .map(Color.init)
    ?? []
}
