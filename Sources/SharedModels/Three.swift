@dynamicMemberLookup
public struct Three<Element>: Sequence {
  public var first: Element {
    get { self.rawValue[0] }
    set { self.rawValue[0] = newValue }
  }
  public var second: Element {
    get { self.rawValue[1] }
    set { self.rawValue[1] = newValue }
  }
  public var third: Element {
    get { self.rawValue[2] }
    set { self.rawValue[2] = newValue }
  }

  public init(_ first: Element, _ second: Element, _ third: Element) {
    self.rawValue = [first, second, third]
  }

  public func map<NewElement>(_ transform: (Element) -> NewElement) -> Three<NewElement> {
    .init(transform(self.first), transform(self.second), transform(self.third))
  }

  public func enumerated() -> Three<(offset: LatticePoint.Index, element: Element)> {
    .init((.zero, self.first), (.one, self.second), (.two, self.third))
  }

  public subscript(
    dynamicMember keyPath: WritableKeyPath<(Element, Element, Element), Element>
  ) -> Element {
    get {
      (self.first, self.second, self.third)[keyPath: keyPath]
    }
    set {
      var three = (self.first, self.second, self.third)
      three[keyPath: keyPath] = newValue
      (self.first, self.second, self.third) = three
    }
  }

  public func makeIterator() -> AnyIterator<Element> {
    var offset = 0
    return AnyIterator {
      defer { offset += 1 }
      switch offset {
      case 0: return self.first
      case 1: return self.second
      case 2: return self.third
      default: return nil
      }
    }
  }

  // NB: public var first, second, third: Element leads to crashes
  private var rawValue: [Element]
}

extension Three: Decodable where Element: Decodable {
  public init(from decoder: Decoder) throws {
    let elements = try [Element](from: decoder)
    guard elements.count == 3 else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: decoder.codingPath,
          debugDescription: "Three contained \(elements.count) elements"
        )
      )
    }
    self.init(elements[0], elements[1], elements[2])
  }
}

extension Three: Encodable where Element: Encodable {
  public func encode(to encoder: Encoder) throws {
    try [self.first, self.second, self.third].encode(to: encoder)
  }
}

extension Three: Equatable where Element: Equatable {}
extension Three: Hashable where Element: Hashable {}
