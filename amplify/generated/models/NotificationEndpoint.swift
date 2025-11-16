// swiftlint:disable all
import Amplify
import Foundation

public struct NotificationEndpoint: Model {
  public let id: String
  public var orgId: String
  public var userId: String
  public var deviceToken: String
  public var platform: NotificationPlatform
  public var deviceName: String?
  public var enabled: Bool
  public var platformEndpointArn: String?
  public var lastUsedAt: Temporal.DateTime?
  public var createdAt: Temporal.DateTime?
  public var updatedAt: Temporal.DateTime?
  
  public init(id: String = UUID().uuidString,
      orgId: String,
      userId: String,
      deviceToken: String,
      platform: NotificationPlatform,
      deviceName: String? = nil,
      enabled: Bool,
      platformEndpointArn: String? = nil,
      lastUsedAt: Temporal.DateTime? = nil,
      createdAt: Temporal.DateTime? = nil,
      updatedAt: Temporal.DateTime? = nil) {
      self.id = id
      self.orgId = orgId
      self.userId = userId
      self.deviceToken = deviceToken
      self.platform = platform
      self.deviceName = deviceName
      self.enabled = enabled
      self.platformEndpointArn = platformEndpointArn
      self.lastUsedAt = lastUsedAt
      self.createdAt = createdAt
      self.updatedAt = updatedAt
  }
}