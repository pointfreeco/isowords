import DictionaryClient
import Foundation
import Gzip
import PuzzleGen
import SharedModels

extension DictionaryClient {
  public static func file(path: String? = nil) -> Self {
    Self(
      contains: { string, language in
        words[language]?.contains(string) == .some(true)
      },
      load: { language in
        guard
          let zipFilePath = Bundle.module.url(
            forResource: "Dictionaries/Words.\(language.rawValue).txt",
            withExtension: "gz"
          )
        else {
          return false
        }

        words[language] = Set(
          String(decoding: try Data(contentsOf: zipFilePath).gunzipped(), as: UTF8.self)
            .split(separator: "\n")
            .map(String.init)
        )

        return words[language] != nil
      },
      lookup: nil,
      randomCubes: { _ in PuzzleGen.randomCubes(for: isowordsLetter).run() },
      unload: { language in
        words[language] = nil
      }
    )
  }
}

private var words: [Language: Set<String>] = [:]
