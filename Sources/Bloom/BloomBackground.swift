import ComposableArchitecture
import Gen
import Styleguide
import SwiftUI

public struct Bloom: Identifiable {
  public let color: UIColor
  public let id: UUID
  public let index: Int
  public let size: CGFloat
  public let offset: CGPoint

  public init(
    color: UIColor,
    id: UUID = .init(),
    index: Int,
    size: CGFloat,
    offset: CGPoint
  ) {
    self.color = color
    self.id = id
    self.index = index
    self.size = size
    self.offset = offset
  }
}

public struct Blooms: View {
  public let blooms: [Bloom]

  public init(blooms: [Bloom]) {
    self.blooms = blooms
  }

  public var body: some View {
    ZStack {
      ForEach(self.blooms) { bloom in
        Rectangle()
          .fill(
            RadialGradient(
              gradient: Gradient(
                colors: [
                  Color(bloom.color),
                  Color(bloom.color).opacity(0),
                ]
              ),
              center: .center,
              startRadius: 0,
              endRadius: bloom.size / 2
            )
          )
          .frame(width: bloom.size, height: bloom.size)
          .offset(x: bloom.offset.x, y: bloom.offset.y)
          .transition(
            .asymmetric(
              insertion: .opacity,
              removal: AnyTransition.opacity.animation(
                .easeInOut(duration: (1 - Double(bloom.index) / Double(self.blooms.count)))
              )
            )
          )
          .zIndex(Double(bloom.index))
      }
    }
  }
}

public struct BloomBackground: View {
  let word: String
  @State var blooms: [Bloom] = []
  @Environment(\.colorScheme) var colorScheme
  let size: CGSize
  @State var vertexGenerator: AnyIterator<CGPoint> = {
    var rng = Xoshiro(seed: 0)
    var vertices: [CGPoint] = [
      .init(x: 0.04, y: 0.04),
      .init(x: 0.04, y: -0.04),
      .init(x: -0.04, y: -0.04),
      .init(x: -0.04, y: 0.04),
    ]
    var index = 0
    return AnyIterator {
      defer { index += 1 }
      if index % vertices.count == 0 {
        vertices.shuffle(using: &rng)
      }
      return vertices[index % vertices.count]
    }
  }()

  public init(size: CGSize, word: String) {
    self.size = size
    self.word = word
  }

  public var body: some View {
    Blooms(blooms: self.blooms)
      .onChange(of: self.word.count) { _, count in
        withAnimation(.easeOut(duration: 1)) {
          self.renderBlooms(count: count)
        }
      }
      .onAppear { self.renderBlooms(count: self.word.count) }
  }

  func renderBlooms(count: Int) {
    if count > self.blooms.count {
      let colors =
        Styleguide.letterColors.first { key, _ in
          key.contains(self.word)
        }?
        .value ?? []
      guard colors.count > 0
      else { return }
      (self.blooms.count..<count).forEach { index in
        let color = colors[index % colors.count]
          .withAlphaComponent(self.colorScheme == .dark ? 0.5 : 1)
        var vertex = vertexGenerator.next()!
        let width = self.size.width * 1.2
        let height = self.size.height * 0.85
        vertex.x *= CGFloat(index) * width
        vertex.y *= CGFloat(index) * height
        let size = (1 + CGFloat(index) * 0.1) * width

        let bloom = Bloom(
          color: color,
          index: self.blooms.count,
          size: size,
          offset: vertex
        )
        self.blooms.append(bloom)
      }
    } else {
      self.blooms.removeLast(self.blooms.count - count)
    }
  }
}
