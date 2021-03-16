import ApplicativeRouter
import Foundation
import Prelude
import Tagged
import UrlFormEncoding

extension PartialIso {
  @inlinable
  public static func `case`(_ embed: @escaping (A) -> B) -> PartialIso {
    return PartialIso(
      apply: embed,
      unapply: { extract(from: $0, via: embed) }
    )
  }
}

extension PartialIso where A == Void {
  @inlinable
  public static func `case`(_ value: B) -> PartialIso {
    let description = "\(value)"
    return PartialIso(
      apply: { _ in value },
      unapply: { "\($0)" == description ? () : nil }
    )
  }
}

extension PartialIso where A == B {
  @inlinable
  public static func `case`(_ embed: @escaping (A) -> B) -> PartialIso {
    return PartialIso(
      apply: embed,
      unapply: embed
    )
  }
}

@inlinable
func extract<Root, Value>(from root: Root, via embed: @escaping (Value) -> Root) -> Value? {
  func extractHelp(from root: Root) -> ([String], Value)? {
    var path: [String] = []
    var any: Any = root
    while case let (label?, anyChild)? = Mirror(reflecting: any).children.first {
      path.append(label)
      path.append(String(describing: type(of: anyChild)))
      if let child = anyChild as? Value {
        return (path, child)
      }
      any = anyChild
    }
    return nil
  }
  guard
    let (rootPath, child) = extractHelp(from: root),
    let (otherPath, _) = extractHelp(from: embed(child)),
    rootPath == otherPath
  else { return nil }
  return child
}

public protocol TaggedType {
  associatedtype Tag
  associatedtype RawValue

  var rawValue: RawValue { get }
  init(rawValue: RawValue)
}

extension Tagged: TaggedType {}

extension PartialIso where B: TaggedType, A == B.RawValue {
  public static var tagged: PartialIso<B.RawValue, B> {
    return PartialIso(
      apply: B.init(rawValue:),
      unapply: ^\.rawValue
    )
  }
}

extension PartialIso {
  /// Promotes a partial iso to one that deals with tagged values, e.g.
  ///
  ///    PartialIso<String, User.Id>.tagged(.string)
  public static func tagged<T, C>(
    _ iso: PartialIso<A, C>
  ) -> PartialIso<A, B>
  where B == Tagged<T, C> {

    return iso >>> .tagged
  }
}

public func parenthesize<A, B, C, D, E, F>(_ f: PartialIso<(A, B, C, D, E), F>) -> PartialIso<
  (A, (B, (C, (D, E)))), F
> {
  return flatten() >>> f
}

public func parenthesize<A, B, C, D, E, F, Z>(_ f: PartialIso<(A, B, C, D, E, F), Z>) -> PartialIso<
  (A, (B, (C, (D, (E, F))))), Z
> {
  return flatten() >>> f
}

private func flatten<A, B, C, D, E>() -> PartialIso<(A, (B, (C, (D, E)))), (A, B, C, D, E)> {
  return .init(
    apply: { ($0.0, $0.1.0, $0.1.1.0, $0.1.1.1.0, $0.1.1.1.1) },
    unapply: { ($0, ($1, ($2, ($3, $4)))) }
  )
}

private func flatten<A, B, C, D, E, F>() -> PartialIso<
  (A, (B, (C, (D, (E, F))))), (A, B, C, D, E, F)
> {
  return .init(
    apply: { ($0.0, $0.1.0, $0.1.1.0, $0.1.1.1.0, $0.1.1.1.1.0, $0.1.1.1.1.1) },
    unapply: { ($0, ($1, ($2, ($3, ($4, $5))))) }
  )
}

extension PartialIso /*A, B*/ {
  static func tuple<C, D>(_ `init`: @escaping (C, D) -> B) -> Self where A == (C, D) {
    Self(
      apply: `init`,
      unapply: { unsafeBitCast($0, to: (C, D).self) }
    )
  }

  static func tuple<C, D, E>(_ `init`: @escaping (C, D, E) -> B) -> Self where A == (C, D, E) {
    Self(
      apply: `init`,
      unapply: { unsafeBitCast($0, to: (C, D, E).self) }
    )
  }
}

extension PartialIso {
  public func `default`<Wrapped>(_ value: Wrapped) -> PartialIso<A, Wrapped> where B == Wrapped? {
    PartialIso<A, Wrapped>(
      apply: { self.apply($0).map { $0 ?? value } },
      unapply: self.unapply
    )
  }
}
