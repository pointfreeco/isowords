import Foundation

extension FileClient {
  public static var live: Self {
    let documentDirectory = FileManager.default
      .urls(for: .documentDirectory, in: .userDomainMask)
      .first!

    return Self(
      delete: { fileName in
        .fireAndForget {
          try? FileManager.default.removeItem(
            at:
              documentDirectory
              .appendingPathComponent(fileName)
              .appendingPathExtension("json")
          )
        }
      },
      load: { fileName in
        .catching {
          try Data(
            contentsOf:
              documentDirectory
              .appendingPathComponent(fileName)
              .appendingPathExtension("json")
          )
        }
      },
      save: { fileName, data in
        .fireAndForget {
          _ = try? data.write(
            to:
              documentDirectory
              .appendingPathComponent(fileName)
              .appendingPathExtension("json")
          )
        }
      }
    )
  }
}
