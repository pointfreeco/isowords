import ComposableArchitecture
import CubeCore
import SharedModels
import SnapshotTesting
import Styleguide
import XCTest

class CubeViewTests: XCTestCase {
  override class func setUp() {
    super.setUp()
    SnapshotTesting.diffTool = "ksdiff"
  }

  override func setUpWithError() throws {
    try super.setUpWithError()
    try XCTSkipIf(!Styleguide.registerFonts())
//    isRecording = true
  }

  func testLetterSurfaceShaderBorderBuffer() throws {
    let json = """
      [
        [
          [
            {
              "wasRemoved": false,
              "top": {
                "letter": "R",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "E",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "N",
                "side": 1,
                "useCount": 0
              }
            },
            {
              "wasRemoved": false,
              "top": {
                "letter": "S",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "W",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "O",
                "side": 1,
                "useCount": 0
              }
            },
            {
              "wasRemoved": false,
              "top": {
                "letter": "Y",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "S",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "A",
                "side": 1,
                "useCount": 0
              }
            }
          ],
          [
            {
              "wasRemoved": false,
              "top": {
                "letter": "A",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "M",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "R",
                "side": 1,
                "useCount": 0
              }
            },
            {
              "wasRemoved": false,
              "top": {
                "letter": "O",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "G",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "O",
                "side": 1,
                "useCount": 0
              }
            },
            {
              "wasRemoved": false,
              "top": {
                "letter": "I",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "B",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "E",
                "side": 1,
                "useCount": 0
              }
            }
          ],
          [
            {
              "wasRemoved": false,
              "top": {
                "letter": "E",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "N",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "H",
                "side": 1,
                "useCount": 0
              }
            },
            {
              "wasRemoved": false,
              "top": {
                "letter": "H",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "N",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "M",
                "side": 1,
                "useCount": 0
              }
            },
            {
              "wasRemoved": false,
              "top": {
                "letter": "T",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "E",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "L",
                "side": 1,
                "useCount": 0
              }
            }
          ]
        ],
        [
          [
            {
              "wasRemoved": false,
              "top": {
                "letter": "B",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "R",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "N",
                "side": 1,
                "useCount": 0
              }
            },
            {
              "wasRemoved": false,
              "top": {
                "letter": "N",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "E",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "A",
                "side": 1,
                "useCount": 0
              }
            },
            {
              "wasRemoved": false,
              "top": {
                "letter": "P",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "E",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "J",
                "side": 1,
                "useCount": 0
              }
            }
          ],
          [
            {
              "wasRemoved": false,
              "top": {
                "letter": "A",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "L",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "B",
                "side": 1,
                "useCount": 0
              }
            },
            {
              "wasRemoved": false,
              "top": {
                "letter": "R",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "I",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "E",
                "side": 1,
                "useCount": 0
              }
            },
            {
              "wasRemoved": false,
              "top": {
                "letter": "F",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "A",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "A",
                "side": 1,
                "useCount": 0
              }
            }
          ],
          [
            {
              "wasRemoved": false,
              "top": {
                "letter": "A",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "N",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "F",
                "side": 1,
                "useCount": 0
              }
            },
            {
              "wasRemoved": false,
              "top": {
                "letter": "C",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "N",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "J",
                "side": 1,
                "useCount": 0
              }
            },
            {
              "wasRemoved": false,
              "top": {
                "letter": "H",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "D",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "K",
                "side": 1,
                "useCount": 0
              }
            }
          ]
        ],
        [
          [
            {
              "wasRemoved": false,
              "top": {
                "letter": "E",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "I",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "S",
                "side": 1,
                "useCount": 0
              }
            },
            {
              "wasRemoved": false,
              "top": {
                "letter": "P",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "E",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "B",
                "side": 1,
                "useCount": 0
              }
            },
            {
              "wasRemoved": false,
              "top": {
                "letter": "E",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "L",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "T",
                "side": 1,
                "useCount": 0
              }
            }
          ],
          [
            {
              "wasRemoved": false,
              "top": {
                "letter": "G",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "B",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "C",
                "side": 1,
                "useCount": 0
              }
            },
            {
              "wasRemoved": false,
              "top": {
                "letter": "E",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "D",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "F",
                "side": 1,
                "useCount": 0
              }
            },
            {
              "wasRemoved": false,
              "top": {
                "letter": "A",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "A",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "E",
                "side": 1,
                "useCount": 0
              }
            }
          ],
          [
            {
              "wasRemoved": false,
              "top": {
                "letter": "Y",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "Y",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "A",
                "side": 1,
                "useCount": 0
              }
            },
            {
              "wasRemoved": false,
              "top": {
                "letter": "I",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "S",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "QU",
                "side": 1,
                "useCount": 0
              }
            },
            {
              "wasRemoved": false,
              "top": {
                "letter": "E",
                "side": 0,
                "useCount": 0
              },
              "right": {
                "letter": "E",
                "side": 2,
                "useCount": 0
              },
              "left": {
                "letter": "T",
                "side": 1,
                "useCount": 0
              }
            }
          ]
        ]
      ]
      """
    let cubes = try JSONDecoder().decode(Puzzle.self, from: Data(json.utf8))

    let view = CubeView(
      store: Store<CubeSceneView.ViewState, CubeSceneView.ViewAction>(
        initialState: .init(
          game: .init(
            cubes: cubes,
            gameContext: .solo,
            gameCurrentTime: .mock,
            gameMode: .unlimited,
            gameStartTime: .mock
          ),
          nub: nil,
          settings: .init()
        ),
        reducer: .empty,
        environment: ()
      )
    )

    assertSnapshot(
      matching: view,
      as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhoneXsMax))
    )
  }
}
