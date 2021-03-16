import Foundation

func shaderSource(fileName: String) -> String {
  try! String(
    contentsOf: Bundle.module.url(forResource: fileName, withExtension: "shader")!,
    encoding: .utf8
  )
}
