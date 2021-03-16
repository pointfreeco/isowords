import Foundation
import Tagged

public enum AccessTokenTag {}
public typealias AccessToken = Tagged<AccessTokenTag, UUID>

public enum DeviceIdTag {}
public typealias DeviceId = Tagged<DeviceIdTag, UUID>

public enum GameCenterLocalPlayerIdTag {}
public typealias GameCenterLocalPlayerId = Tagged<GameCenterLocalPlayerIdTag, String>
