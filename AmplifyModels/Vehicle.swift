// swiftlint:disable all
import Amplify
import Foundation

public struct Vehicle: Model {
  public let id: String
  public var orgId: String
  public var callsign: String
  public var make: String?
  public var model: String?
  public var plate: String?
  public var inService: Bool?
  public var updatedAt: Temporal.DateTime
  public var createdAt: Temporal.DateTime
  
  public init(id: String = UUID().uuidString,
      orgId: String,
      callsign: String,
      make: String? = nil,
      model: String? = nil,
      plate: String? = nil,
      inService: Bool? = nil,
      updatedAt: Temporal.DateTime,
      createdAt: Temporal.DateTime) {
      self.id = id
      self.orgId = orgId
      self.callsign = callsign
      self.make = make
      self.model = model
      self.plate = plate
      self.inService = inService
      self.updatedAt = updatedAt
      self.createdAt = createdAt
  }
}