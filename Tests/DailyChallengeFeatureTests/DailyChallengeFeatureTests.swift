import ClientModels
import ComposableArchitecture
import XCTest

@testable import DailyChallengeFeature
@testable import SharedModels

extension DailyChallengeEnvironment {
  static let failing = Self(
    apiClient: .failing,
    fileClient: .failing,
    mainQueue: .failing,
    mainRunLoop: .failing,
    remoteNotifications: .failing,
    userNotifications: .failing
  )
}

class DailyChallengeFeatureTests: XCTestCase {
  func testBasics() {
    var environment = DailyChallengeEnvironment.failing
    environment.mainRunLoop = .immediate
    environment.apiClient.override(
      route: .dailyChallenge(.today(language: .en)),
      withResponse: .ok([FetchTodaysDailyChallengeResponse.played])
    )
    environment.userNotifications.getNotificationSettings = .init(
      value: .init(authorizationStatus: .authorized)
    )
    
    let store = TestStore(
      initialState: DailyChallengeState(),
      reducer: dailyChallengeReducer,
      environment: environment
    )
    store.send(.onAppear)
    store.receive(.fetchTodaysDailyChallengeResponse(.success([.played]))) {
      $0.dailyChallenges = [.played]
    }
    store.receive(.userNotificationSettingsResponse(.init(authorizationStatus: .authorized))) {
      $0.userNotificationSettings = .init(authorizationStatus: .authorized)
    }
  }
}
