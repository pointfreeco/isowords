import Build
import ComposableArchitecture
import ServerConfigClient
import SwiftUI
import Tagged

@Reducer
public struct Change {
  @ObservableState
  public struct State: Equatable, Identifiable {
    public var change: Changelog.Change
    public var isExpanded = false

    public var id: Build.Number {
      self.change.build
    }
  }

  public enum Action: Equatable {
    case showButtonTapped
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .showButtonTapped:
        state.isExpanded.toggle()
        return .none
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
        Text(self.store.change.version)
          .font(.title)

        if self.store.change.build == self.currentBuild {
          Text("Installed")
            .font(.footnote)
            .padding(.grid(1))
            .foregroundColor(.white)
            .background(Color.gray)
        }

        Spacer()

        if !self.store.isExpanded {
          Button("Show") {
            self.store.send(.showButtonTapped, animation: .default)
          }
        }
      }

      if self.store.isExpanded {
        Text(self.store.change.log)
      }
    }
    .buttonStyle(PlainButtonStyle())
  }
}
