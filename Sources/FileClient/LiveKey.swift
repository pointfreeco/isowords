//import Dependencies
//import Foundation
//
//extension FileClient: DependencyKey {
//  public static let liveValue = {
//    let documentDirectory = FileManager.default
//      .urls(for: .documentDirectory, in: .userDomainMask)
//      .first!
//
//    return Self(
//      delete: {
//        try FileManager.default.removeItem(
//          at: documentDirectory.appendingPathComponent($0).appendingPathExtension("json")
//        )
//      },
//      load: {
//        try Data(
//          contentsOf: documentDirectory.appendingPathComponent($0).appendingPathExtension("json")
//        )
//      },
//      save: {
//        try $1.write(
//          to: documentDirectory.appendingPathComponent($0).appendingPathExtension("json")
//        )
//      }
//    )
//  }()
//}
