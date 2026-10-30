import ApiClient
import Build
import ComposableArchitecture
import Dependencies
import ServerConfigClient
import SharedModels
import Styleguide
import SwiftUI
import Tagged
import UIApplicationClient

@Feature
public struct ChangelogReducer {
  public struct State {
    public var changelog: [Change.State]
    public var currentBuild: Build.Number
    public var isRequestInFlight: Bool
    public var isUpdateButtonVisible: Bool

    public init(
      changelog: [Change.State] = [],
      currentBuild: Build.Number = 0,
      isRequestInFlight: Bool = false,
      isUpdateButtonVisible: Bool = false
    ) {
      self.changelog = changelog
      self.currentBuild = currentBuild
      self.isRequestInFlight = isRequestInFlight
      self.isUpdateButtonVisible = isUpdateButtonVisible
    }

    public var whatsNew: [Change.State] {
      changelog.filter { $0.change.build >= currentBuild }
    }

    public var pastUpdates: [Change.State] {
      changelog.filter { $0.change.build < currentBuild }
    }
  }

  public enum Action {
    case changelog(Change.State.ID, Change.Action)
    case updateButtonTapped
  }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.build.number) var buildNumber
  @Dependency(\.applicationClient.open) var openURL
  @Dependency(\.serverConfig) var serverConfig

  public init() {}

  public var body: some Feature {
    Update { state, action in
      switch action {
      case .changelog:
        break

      case .updateButtonTapped:
        store.addTask {
          _ = await openURL(
            serverConfig.config().appStoreUrl.absoluteURL,
            [:]
          )
        }
      }
    }
    .forEach(\.changelog) {
      Change()
    }
    .onMount { state in
      state.currentBuild = buildNumber()
      state.isRequestInFlight = true

      store.addTask {
        do {
          let changelog = try await apiClient.apiRequest(
            route: .changelog(build: buildNumber()),
            as: Changelog.self
          )
          let buildNumber = buildNumber()
          try store.modify {
            $0.changelog =
              changelog
              .changes
              .sorted(by: { $0.build > $1.build })
              .enumerated()
              .map { offset, change in
                Change.State(
                  change: change,
                  isExpanded: offset == 0 || buildNumber <= change.build
                )
              }
            $0.isRequestInFlight = false
            $0.isUpdateButtonVisible =
              buildNumber < (changelog.changes.map(\.build).max() ?? 0)
          }
        } catch is CancellationError {
        } catch {
          try store.modify { $0.isRequestInFlight = false }
        }
      }
    }
  }
}

public struct ChangelogView: View {
  let store: StoreOf<ChangelogReducer>

  public init(store: StoreOf<ChangelogReducer>) {
    self.store = store
  }

  public var body: some View {
    let changes = store.scope(\.changelog)
    ScrollView {
      VStack(alignment: .leading) {
        if store.isUpdateButtonVisible {
          HStack {
            Spacer()
            Button("Update") {
              store.send(.updateButtonTapped)
            }
            .buttonStyle(ActionButtonStyle())
          }
        }

        Text("What's new?")
          .font(.largeTitle)

        ForEach(changes.filter { $0.change.build >= store.currentBuild }) { store in
          ChangeView(currentBuild: self.store.currentBuild, store: store)
        }

        Text("Past updates")
          .font(.largeTitle)

        ForEach(changes.filter { $0.change.build < store.currentBuild }) { store in
          ChangeView(currentBuild: self.store.currentBuild, store: store)
        }
      }
      .padding()
    }
  }
}

#if DEBUG
  import Overture
  import SwiftUIHelpers

  struct ChangelogPreviews: PreviewProvider {
    static var previews: some View {
      Preview {
        ChangelogView(
          store: Store(initialState: ChangelogReducer.State()) {
            ChangelogReducer()
              .dependency(
                \.apiClient,
                {
                  var apiClient = ApiClient.noop
                  apiClient.override(
                    routeCase: \.changelog,
                    withResponse: { _ in
                      try await OK(
                        update(Changelog.current) {
                          $0.changes.append(
                            Changelog.Change(
                              version: "1.0",
                              build: 60,
                              log: "We launched!"
                            )
                          )
                        }
                      )
                    }
                  )
                  return apiClient
                }()
              )
              .dependency(\.applicationClient, .noop)
              .dependency(\.build.number, { 98 })
              .dependency(\.serverConfig, .noop)
          }
        )
        .navigationStyle(
          title: Text("Updates"),
          navPresentationStyle: .modal,
          onDismiss: {}
        )
      }
    }
  }
#endif
