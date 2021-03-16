import SnapshotTesting
import SwiftUI

struct Snapshot<Content>: View where Content: View {
  let content: () -> Content
  @State var image: Image?
  let snapshotting: Snapshotting<AnyView, UIImage>

  init(
    _ snapshotting: Snapshotting<AnyView, UIImage>,
    @ViewBuilder _ content: @escaping () -> Content
  ) {
    self.content = content
    self.snapshotting = snapshotting
  }

  var body: some View {
    ZStack {
      self.image?
        .resizable()
        .aspectRatio(contentMode: .fit)
    }
    .onAppear {
      self.snapshotting
        .snapshot(AnyView(self.content()))
        .run { self.image = Image(uiImage: $0) }
    }
  }
}
