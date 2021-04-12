import SceneKit
import SwiftUI

class LetterGeometry: SCNPlane {
  override init() {
    super.init()
  }

  func loadShaders(
    puzzle: CubeSceneView.ViewState.ViewPuzzle,
    worldScale: Float
  ) {
    self.firstMaterial?.lightingModel = .constant
    self.shaderModifiers = [
      .geometry: shaderSource(fileName: "Face.geometry"),
      .surface: shaderSource(fileName: "Letter.surface"),
    ]
    self.setValue(letterTileSize, forKey: .letterTextureSize)
    self.setValue(worldScale, forKey: .worldScale)
    self.setValue(
      SCNMaterialProperty(contents: lettersBitmap(puzzle)),
      forKey: .lettersTexture
    )
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension String {
  fileprivate static let letterTextureSize = "letterTextureSize"
  fileprivate static let lettersTexture = "lettersTexture"
  fileprivate static let worldScale = "worldScale"
  fileprivate static let textColor = "textColor"
}

private func lettersBitmap(
  _ puzzle: CubeSceneView.ViewState.ViewPuzzle
) -> UIImage {
  UIGraphicsBeginImageContext(
    .init(
      width: columnCount * letterTileSize,
      height: rowCount * letterTileSize
    )
  )

  var index = 0
  for xSlice in puzzle {
    for ySlice in xSlice {
      for cubeViewState in ySlice {
        [cubeViewState.left, cubeViewState.right, cubeViewState.top].forEach { faceViewState in
          defer { index += 1 }

          UIImage(named: faceViewState.cubeFace.letter.rawValue, in: Bundle.module, with: nil)!
            .draw(
              in: .init(
                x: (index % columnCount) * letterTileSize,
                y: (index / rowCount) * letterTileSize,
                width: letterTileSize,
                height: letterTileSize
              )
            )
        }
      }
    }
  }

  let image = UIGraphicsGetImageFromCurrentImageContext()!
  return image
}

private let letterTileSize = 256
private let rowCount = 9
private let columnCount = 9
