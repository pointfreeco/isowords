import Build
import ComposableArchitecture
import ServerConfigClient
import Styleguide
import SwiftUI
import UIApplicationClient

public struct ChangeState: Equatable, Identifiable {
  public var change: Changelog.Change
  public var isExpanded = false

  public var id: Build.Number {
    self.change.build
  }
}

public enum ChangeAction: Equatable {
  case showButtonTapped
}

public struct ChangeEnvironment {
  public var applicationClient: UIApplicationClient
  public var serverConfig: ServerConfigClient
}

let changeReducer = Reducer<
  ChangeState,
  ChangeAction,
  ChangeEnvironment
> { state, action, environment in
  switch action {
  case .showButtonTapped:
    state.isExpanded.toggle()
    return .none
  }
}

struct ChangeView: View {
  var currentBuild: Build.Number
  let store: Store<ChangeState, ChangeAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack(alignment: .leading, spacing: .grid(2)) {
        HStack {
          Text(viewStore.change.version)
            .font(.title)

          if viewStore.change.build == self.currentBuild {
            Text("Installed")
              .font(.footnote)
              .padding(.grid(1))
              .foregroundColor(.white)
              .background(Color.gray)
          }

          Spacer()

          if !viewStore.isExpanded {
            Button(action: { viewStore.send(.showButtonTapped, animation: .default) }) {
              Text("Show")
            }
          }
        }

        if viewStore.isExpanded {
          Text(viewStore.change.log)
        }
      }
      .adaptivePadding([.vertical])
    }
    .buttonStyle(PlainButtonStyle())
  }
}
