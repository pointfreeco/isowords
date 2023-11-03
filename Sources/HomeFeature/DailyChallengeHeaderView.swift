import ComposableArchitecture
import DailyChallengeFeature
import DateHelpers
import SharedModels
import Styleguide
import SwiftUI

struct DailyChallengeHeaderView: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.date) var date
  @State var store: StoreOf<Home>

  init(store: StoreOf<Home>) {
    self._store = State(wrappedValue: store)
  }

  var body: some View {
    let numberOfPlayers = self.store.dailyChallenges?.reduce(into: 0) {
      $0 += $1.yourResult.outOf
    }

    VStack(alignment: .leading, spacing: 20) {
      VStack(alignment: .center, spacing: -.grid(2)) {
        if self.hasPlayedAllDailyChallenges {
          Text("Next daily")
            .foregroundColor(colorScheme == .dark ? yellow1 : .isowordsBlack)
          Text("challenge")
            .foregroundColor(colorScheme == .dark ? yellow2 : .isowordsBlack)
          Text("starts in")
            .foregroundColor(colorScheme == .dark ? yellow3 : .isowordsBlack)
          (Text(timeDescriptionUntilTomorrow(now: self.date())) + Text("."))
            .fontWeight(.medium)
            .foregroundColor(colorScheme == .dark ? yellow4 : .isowordsBlack)
        } else {
          Text("Today’s")
            .foregroundColor(colorScheme == .dark ? yellow1 : .isowordsBlack)
          Text("challenge")
            .foregroundColor(colorScheme == .dark ? yellow2 : .isowordsBlack)
          Text("ends in")
            .foregroundColor(colorScheme == .dark ? yellow3 : .isowordsBlack)
          (Text(timeDescriptionUntilTomorrow(now: self.date())) + Text("!"))
            .fontWeight(.medium)
            .foregroundColor(colorScheme == .dark ? yellow4 : .isowordsBlack)
        }
      }
      .adaptiveFont(.matter, size: 56)
      .adaptivePadding(.bottom)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity)

      VStack {
        Button {
          self.store.send(.dailyChallengeButtonTapped)
        } label: {
          HStack {
            Group {
              if self.hasPlayedAllDailyChallenges {
                Text("View results")
              } else {
                Text("Play now")
              }
            }
            Spacer()
            Image(systemName: "arrow.right")
          }
        }
        .buttonStyle(
          ActionButtonStyle(
            backgroundColor: self.colorScheme == .dark ? yellow5 : .isowordsBlack,
            foregroundColor: self.colorScheme == .dark ? .isowordsBlack : yellow5
          )
        )

        Group {
          if let numberOfPlayers = numberOfPlayers {
            if numberOfPlayers == 0 {
              Text("No one has played. Be the first!")
            } else if self.hasPlayedAllDailyChallenges {
              if numberOfPlayers - 1 == 1 {
                Text("You and ")
                  + Text("\(numberOfPlayers - 1)").fontWeight(.medium)
                  + Text(" person has played!")
              } else {
                Text("You and ")
                  + Text("\(numberOfPlayers - 1)").fontWeight(.medium)
                  + Text(" people have played!")
              }
            } else {
              if numberOfPlayers == 1 {
                Text("\(numberOfPlayers)").fontWeight(.medium)
                  + Text(" person has already played!")
              } else {
                Text("\(numberOfPlayers)").fontWeight(.medium)
                  + Text(" people have already played!")
              }
            }
          } else {
            Text("No one has played. Be the first!")
              .redacted(reason: .placeholder)
          }
        }
        .foregroundColor(self.colorScheme == .dark ? yellow6 : .isowordsBlack)
        .adaptiveFont(.matter, size: 12)
        .padding(.top)
      }
    }
    .navigationDestination(
      item: self.$store.scope(
        state: \.destination?.dailyChallenge, action: \.destination.dailyChallenge
      )
    ) { store in
      DailyChallengeView(store: store)
    }
  }

  var hasPlayedAllDailyChallenges: Bool {
    self.store.dailyChallenges
      .map { $0.allSatisfy { $0.yourResult.rank != nil } }
      ?? false
  }
}

private let yellow1 = Color.hex(0xF1DC9C)
private let yellow2 = Color.hex(0xF1D798)
private let yellow3 = Color.hex(0xEFCC94)
private let yellow4 = Color.hex(0xEFC790)
private let yellow5 = Color.hex(0xEDBE8B)
private let yellow6 = Color.hex(0xECB788)

#if DEBUG
  struct DailyChallengeHeaderViewPreviews: PreviewProvider {
    static var previews: some View {
      Group {
        NavigationView {
          DailyChallengeHeaderView(store: .home)
        }
        .environment(\.colorScheme, .light)

        NavigationView {
          DailyChallengeHeaderView(store: .home)
        }
        .environment(\.colorScheme, .dark)
      }
    }
  }
#endif
