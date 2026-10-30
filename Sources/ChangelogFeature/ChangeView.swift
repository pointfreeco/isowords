import Build
import ComposableArchitecture
import ServerConfigClient
import SwiftUI
import Tagged

@Feature
public struct Change {
  public struct State: Identifiable {
    public var change: Changelog.Change
    public var isExpanded = false

    public var id: Build.Number {
      self.change.build
    }
  }

  public enum Action {
    case showButtonTapped
  }

  public init() {}

  public var body: some Feature {
    Update { state, action in
      switch action {
      case .showButtonTapped:
        state.isExpanded.toggle()
      }
    }
  }
}

struct ChangeView: View {
  var currentBuild: Build.Number
  let store: StoreOf<Change>

  var body: some View {
    VStack(alignment: .leading, spacing: .grid(2)) {
      HStack {
        Text(store.change.version)
          .font(.title)

        if store.change.build == self.currentBuild {
          Text("Installed")
            .font(.footnote)
            .padding(.grid(1))
            .foregroundColor(.white)
            .background(Color.gray)
        }

        Spacer()

        if !store.isExpanded {
          Button("Show") {
            withAnimation { _ = store.send(.showButtonTapped) }
          }
        }
      }

      if store.isExpanded {
        Text(store.change.log)
      }
    }
    .adaptivePadding(.vertical)
    .buttonStyle(PlainButtonStyle())
  }
}
