import HttpPipeline
import Prelude

public func appSiteAssociationMiddleware(
  _ conn: Conn<StatusLineOpen, Void>
) -> IO<Conn<HeadersOpen, AppSiteAssociation>> {
  conn.map(
    const(
      AppSiteAssociation(
        appClips: .init(
          apps: [
            "479VDHY7L8.co.pointfree.IsoWordsTesting.Clip",
            "VFRXY8HC3H.co.pointfree.IsoWordsTesting.Clip",
          ]
        ),
        appLinks: .init(
          details: [
            .init(
              appIDs: [
                "479VDHY7L8.co.pointfree.IsoWordsTesting",
                "VFRXY8HC3H.co.pointfree.IsoWordsTesting",
              ],
              components: [
                .init(path: "*")
              ]
            )
          ]
        )
      )
    )
  )
    |> writeStatus(.ok)
}

public struct AppSiteAssociation: Codable, Equatable {
  var appClips: AppClips? = nil
  var appLinks: AppLinks? = nil
  var webCredentials: WebCredentials? = nil

  private enum CodingKeys: String, CodingKey {
    case appClips = "appclips"
    case appLinks = "applinks"
    case webCredentials = "webcredentials"
  }

  struct AppClips: Codable, Equatable {
    var apps: [String] = []
  }

  struct AppLinks: Codable, Equatable {
    var defaults: Defaults? = nil
    var details: [Detail] = []

    struct Defaults: Codable, Equatable {
      var caseSensitive: Bool? = nil
      var percentEncoded: Bool? = nil
    }

    struct Detail: Codable, Equatable {
      var appIDs: [String] = []
      var components: [Component] = []
      var defaults: Defaults? = nil

      struct Component: Codable, Equatable {
        var caseSensitive: Bool? = nil
        var comment: String? = nil
        var exclude: Bool? = nil
        var fragment: String? = nil
        var path: String? = nil
        var percentEncoded: Bool? = nil
        var query: [String: String]? = nil

        private enum CodingKeys: String, CodingKey {
          case caseSensitive = "caseSensitive"
          case comment = "comment"
          case exclude = "exclude"
          case fragment = "#"
          case path = "/"
          case percentEncoded = "percentEncoded"
          case query = "?"
        }
      }
    }
  }

  struct WebCredentials: Codable, Equatable {
    var apps: [String] = []
  }
}
