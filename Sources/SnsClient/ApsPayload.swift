public struct NoContent: Codable, Equatable {}

public struct ApsPayload<Content> {
  public let aps: Aps
  public let content: Content

  public init(
    aps: Aps,
    content: Content
  ) {
    self.aps = aps
    self.content = content
  }

  private enum CodingKeys: String, CodingKey {
    case aps
  }

  public struct Aps: Codable, Equatable {
    public let alert: Alert
    public let badge: Int?
    public let contentAvailable: Bool?

    public init(
      alert: Alert,
      badge: Int? = nil,
      contentAvailable: Bool? = nil
    ) {
      self.alert = alert
      self.badge = badge
      self.contentAvailable = contentAvailable
    }

    private enum CodingKeys: String, CodingKey {
      case alert
      case badge
      case contentAvailable = "content-available"
    }

    public struct Alert: Codable, Equatable {
      public let actionLocalizedKey: String?
      public let body: String?
      public let localizedArguments: [String]?
      public let localizedKey: String?
      public let sound: String?
      public let title: String?

      public init(
        actionLocalizedKey: String? = nil,
        body: String? = nil,
        localizedArguments: [String]? = nil,
        localizedKey: String? = nil,
        sound: String? = nil,
        title: String? = nil
      ) {
        self.actionLocalizedKey = actionLocalizedKey
        self.body = body
        self.localizedArguments = localizedArguments
        self.localizedKey = localizedKey
        self.sound = sound
        self.title = title
      }

      private enum CodingKeys: String, CodingKey {
        case actionLocalizedKey = "action-loc-key"
        case body
        case localizedArguments = "loc-args"
        case localizedKey = "loc-key"
        case sound
        case title
      }
    }
  }
}

extension ApsPayload where Content == NoContent {
  public init(aps: Aps) {
    self.aps = aps
    self.content = NoContent()
  }
}

extension ApsPayload: Equatable where Content: Equatable {}

extension ApsPayload: Decodable where Content: Decodable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.aps = try container.decode(Aps.self, forKey: .aps)
    self.content = try Content(from: decoder)
  }
}

extension ApsPayload: Encodable where Content: Encodable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.aps, forKey: .aps)
    try self.content.encode(to: encoder)
  }
}
