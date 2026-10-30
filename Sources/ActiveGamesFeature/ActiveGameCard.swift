import SwiftUI

struct ActiveGameCard<Title: View, Message: View>: View {
  var button: ActiveGameCardButton
  @Environment(\.colorScheme) var colorScheme
  var message: Message
  var tapAction: () -> Void
  var buttonAction: (() -> Void)? = nil
  var title: Title

  enum AnimationStep {
    case icon
    case title
  }

  @State var isAnimating = AnimationStep?.none {
    didSet {
      guard button.shouldAnimate else { return }
      switch self.isAnimating {
      case .icon:
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          withAnimation(
            .interpolatingSpring(mass: 0.5, stiffness: 10, damping: 10, initialVelocity: 2)
          ) { self.isAnimating = .title }
        }
      case .title:
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          withAnimation { self.isAnimating = nil }
        }
      case .none:
        return
      }
    }
  }

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      Button(action: tapAction) {
        VStack(alignment: .leading, spacing: 0) {
          title
            .lineLimit(1)
            .padding(.all, .grid(3))
            .adaptiveFont(.matterMedium, size: 12)
            .opacity(0.5)
            .foregroundColor(colorScheme == .light ? .isowordsOrange : .isowordsBlack)

          Divider()
            .background(
              (colorScheme == .light ? Color.isowordsOrange : .isowordsBlack)
                .opacity(0.3)
            )

          message
            .padding(.all, .grid(3))
            .adaptiveFont(.matterMedium, size: 16)
            .foregroundColor(colorScheme == .light ? .isowordsOrange : .isowordsBlack)

          Spacer()
        }
      }
      .buttonStyle(
        ActiveGameButtonStyle(
          backgroundColor: colorScheme == .light ? .isowordsBlack : .isowordsOrange,
          foregroundColor: colorScheme == .light ? .isowordsOrange : .isowordsBlack
        )
      )

      Group {
        if button.isActive {
          Button {
            (buttonAction ?? tapAction)()
            guard button.shouldAnimate else { return }
            withAnimation(.interactiveSpring()) { isAnimating = .icon }
          } label: {
            HStack(alignment: .firstTextBaseline, spacing: .grid(1)) {
              button.icon?
                .offset(x: button.shouldAnimate && isAnimating == .icon ? 8 : 0)
              button.title
                .offset(x: button.shouldAnimate && isAnimating == .title ? 6 : 0)
            }
            .padding(.vertical, .grid(2))
            .padding(.leading, .grid(3))
            .padding(.trailing, .grid(4))
            .foregroundColor(colorScheme == .light ? .isowordsBlack : .isowordsOrange)
            .background(
              Capsule().fill(colorScheme == .light ? Color.isowordsOrange : .isowordsBlack)
            )
            .adaptiveFont(.matterMedium, size: 12)
          }
          .buttonStyle(PlainButtonStyle())
        } else {
          button.title
            .padding(.bottom, .grid(2))
            .adaptiveFont(.matterMedium, size: 12)
            .foregroundColor(colorScheme == .light ? .isowordsOrange : .isowordsBlack)
            .opacity(0.5)
        }
      }
      .padding(.horizontal, .grid(3))
      .padding(.bottom, .grid(4))
      .adaptiveFont(.matterMedium, size: 12)
    }
    .frame(width: 180, height: 220)
  }
}

struct ActiveGameCardButton {
  let icon: Image?
  let isActive: Bool
  var shouldAnimate = false
  let title: Text
}

#if DEBUG
  import SwiftUIHelpers

  struct ActiveGameCard_Previews: PreviewProvider {
    static var previews: some View {
      Preview {
        NavigationView {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top) {
              ActiveGameCard(
                button: .init(
                  icon: Image(systemName: "arrow.right"),
                  isActive: true,
                  title: Text("Your turn")
                ),
                message: VStack(alignment: .leading) {
                  HStack(spacing: .grid(1)) {
                    Image(systemName: "person.crop.circle")
                    Text("mbrandonw")
                  }
                  .lineLimit(1)
                  .truncationMode(.tail)

                  Text("played ")
                    + Text("dreamer")
                    + Text("230")
                    .baselineOffset(10.0)
                    .font(.system(size: 12))
                    .fontWeight(.medium)
                },
                tapAction: {},
                title: Text("vs mbrandonw")
              )

              ActiveGameCard(
                button: .init(
                  icon: Image(systemName: "hand.point.right.fill"),
                  isActive: false,
                  title: Text("Your turn")
                ),
                message: Text("2 hours\n").fontWeight(.medium) + Text("left to play!"),
                tapAction: {},
                title: Text("Daily challenge")
              )

              ActiveGameCard(
                button: .init(
                  icon: Image(systemName: "hand.point.right.fill"),
                  isActive: true,
                  title: Text("Poke")
                ),
                message: Text(
                  "\(Image(systemName: "person.crop.circle")) mbrandow hasn’t played in a while"),
                tapAction: {},
                title: Text("vs mbrandonw")
              )
            }
            .padding()
          }
        }
      }
    }
  }
#endif
