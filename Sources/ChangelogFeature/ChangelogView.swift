import ApiClient
import Build
import ComposableArchitecture
import ServerConfigClient
import SharedModels
import Styleguide
import SwiftUI
import Tagged
import UIApplicationClient

@Reducer
public struct ChangelogReducer {
  @ObservableState
  public struct State: Equatable {
    public var changelog: IdentifiedArrayOf<Change.State>
    public var currentBuild: Build.Number
    public var isRequestInFlight: Bool
    public var isUpdateButtonVisible: Bool

    public init(
      changelog: IdentifiedArrayOf<Change.State> = [],
      currentBuild: Build.Number = 0,
      isRequestInFlight: Bool = false,
      isUpdateButtonVisible: Bool = false
    ) {
      self.changelog = changelog
      self.currentBuild = currentBuild
      self.isRequestInFlight = isRequestInFlight
      self.isUpdateButtonVisible = isUpdateButtonVisible
    }

    public var whatsNew: IdentifiedArrayOf<Change.State> {
      self.changelog.filter { $0.change.build >= self.currentBuild }
    }

    public var pastUpdates: IdentifiedArrayOf<Change.State> {
      self.changelog.filter { $0.change.build < self.currentBuild }
    }
  }

  public enum Action {
    case changelog(IdentifiedActionOf<Change>)
    case changelogResponse(Result<Changelog, Error>)
    case task
    case updateButtonTapped
  }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.build.number) var buildNumber
  @Dependency(\.applicationClient.open) var openURL
  @Dependency(\.serverConfig) var serverConfig

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .changelog:
        return .none

      case let .changelogResponse(.success(changelog)):
        state.changelog = IdentifiedArray(
          uniqueElements:
            changelog
            .changes
            .sorted(by: { $0.build > $1.build })
            .enumerated()
            .map { offset, change in
              Change.State(
                change: change,
                isExpanded: offset == 0 || self.buildNumber() <= change.build
              )
            }
        )
        state.isRequestInFlight = false
        state.isUpdateButtonVisible =
          self.buildNumber() < (changelog.changes.map(\.build).max() ?? 0)

        return .none

      case .changelogResponse(.failure):
        state.isRequestInFlight = false
        return .none

      case .task:
        state.currentBuild = self.buildNumber()
        state.isRequestInFlight = true

        return .run { send in
          await send(
            .changelogResponse(
              Result {
                try await self.apiClient.apiRequest(
                  route: .changelog(build: self.buildNumber()),
                  as: Changelog.self
                )
              }
            )
          )
        }

      case .updateButtonTapped:
        return .run { _ in
          _ = await self.openURL(
            self.serverConfig.config().appStoreUrl.absoluteURL,
            [:]
          )
        }
      }
    }
    .forEach(\.changelog, action: \.changelog) {
      Change()
    }
  }
}

public struct ChangelogView: View {
  let store: StoreOf<ChangelogReducer>

  public init(store: StoreOf<ChangelogReducer>) {
    self.store = store
  }

  public var body: some View {
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

        ForEach(store.scope(state: \.whatsNew, action: \.changelog)) { store in
          ChangeView(currentBuild: self.store.currentBuild, store: store)
        }

        Text("Past updates")
          .font(.largeTitle)

        ForEach(store.scope(state: \.pastUpdates, action: \.changelog)) { store in
          ChangeView(currentBuild: self.store.currentBuild, store: store)
        }
      }
      .padding()
    }
    .task { await store.send(.task).finish() }
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
          } withDependencies: {
            $0.apiClient = {
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
            $0.applicationClient = .noop
            $0.build.number = { 98 }
            $0.serverConfig = .noop
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
