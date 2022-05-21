import ApiClient
import Build
import ComposableArchitecture
import ServerConfigClient
import SharedModels
import Styleguide
import SwiftUI
import TcaHelpers
import UIApplicationClient

public struct ChangelogFeature: ReducerProtocol {
  public struct State: Equatable {
    public var changelog: IdentifiedArrayOf<ChangeFeature.State>
    public var currentBuild: Build.Number
    public var isRequestInFlight: Bool
    public var isUpdateButtonVisible: Bool

    public init(
      changelog: IdentifiedArrayOf<ChangeFeature.State> = [],
      currentBuild: Build.Number = 0,
      isRequestInFlight: Bool = false,
      isUpdateButtonVisible: Bool = false
    ) {
      self.changelog = changelog
      self.currentBuild = currentBuild
      self.isRequestInFlight = isRequestInFlight
      self.isUpdateButtonVisible = isUpdateButtonVisible
    }
  }

  public enum Action: Equatable {
    case change(id: Build.Number, action: ChangeFeature.Action)
    case changelogResponse(Result<Changelog, ApiError>)
    case onAppear
    case updateButtonTapped
  }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.applicationClient) var applicationClient
  @Dependency(\.build) var build
  @Dependency(\.mainQueue) var mainQueue
  @Dependency(\.serverConfig) var serverConfig

  public init() {}

  public var body: some ReducerProtocol<State, Action> {
    ForEachReducer(state: \.changelog, action: /Action.change(id:action:)) {
      ChangeFeature()
    }

    Reduce { state, action in
      switch action {
      case .change:
        return .none

      case let .changelogResponse(.success(changelog)):
        state.changelog = IdentifiedArray(
          uniqueElements:
            changelog
            .changes
            .sorted(by: { $0.build > $1.build })
            .enumerated()
            .map { offset, change in
              .init(
                change: change,
                isExpanded: offset == 0 || self.build.number() <= change.build
              )
            }
        )
        state.isRequestInFlight = false
        state.isUpdateButtonVisible =
          self.build.number() < (changelog.changes.map(\.build).max() ?? 0)

        return .none

      case .changelogResponse(.failure):
        state.isRequestInFlight = false
        return .none

      case .onAppear:
        state.currentBuild = self.build.number()
        state.isRequestInFlight = true

        return self.apiClient.apiRequest(
          route: .changelog(build: self.build.number()),
          as: Changelog.self
        )
        .receive(on: self.mainQueue)
        .catchToEffect(Action.changelogResponse)

      case .updateButtonTapped:
        return self.applicationClient.open(
          self.serverConfig.config().appStoreUrl.absoluteURL,
          [:]
        )
        .fireAndForget()
      }
    }
  }
}

public struct ChangelogView: View {
  let store: StoreOf<ChangelogFeature>

  struct ViewState: Equatable {
    let currentBuild: Build.Number
    let isUpdateButtonVisible: Bool

    init(state: ChangelogFeature.State) {
      self.currentBuild = state.currentBuild
      self.isUpdateButtonVisible = state.isUpdateButtonVisible
    }
  }

  public init(
    store: StoreOf<ChangelogFeature>
  ) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store.scope(state: ViewState.init)) { viewStore in
      ScrollView {
        VStack(alignment: .leading) {
          if viewStore.isUpdateButtonVisible {
            HStack {
              Spacer()
              Button(action: { viewStore.send(.updateButtonTapped) }) {
                Text("Update")
              }
              .buttonStyle(ActionButtonStyle())
            }
          }

          Text("What's new?")
            .font(.largeTitle)

          ForEachStore(
            self.store.scope(
              state: { $0.changelog.filter { $0.change.build >= viewStore.currentBuild } },
              action: ChangelogFeature.Action.change(id:action:)
            ),
            content: { ChangeView(currentBuild: viewStore.currentBuild, store: $0) }
          )

          Text("Past updates")
            .font(.largeTitle)

          ForEachStore(
            self.store.scope(
              state: { $0.changelog.filter { $0.change.build < viewStore.currentBuild } },
              action: ChangelogFeature.Action.change(id:action:)
            ),
            content: { ChangeView(currentBuild: viewStore.currentBuild, store: $0) }
          )
        }
        .padding()
      }
      .onAppear { viewStore.send(.onAppear) }
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
          store: .init(
            initialState: .init(),
            reducer: ChangelogFeature()
              .dependency(
                \.apiClient,
                update(.noop) {
                  $0.override(
                    routeCase: /ServerRoute.Api.Route.changelog(build:),
                    withResponse: { _ in
                      .ok(
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
                }
              )
              .dependency(\.applicationClient, .noop)
              .dependency(\.build, update(.noop) { $0.number = { 98 }})
              .dependency(\.mainQueue, .immediate)
              .dependency(\.serverConfig, .noop)
          )
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
