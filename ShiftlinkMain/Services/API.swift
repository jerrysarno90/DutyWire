//  This file was automatically generated and should not be edited.

#if canImport(AWSAPIPlugin)
import Foundation

public protocol GraphQLInputValue {
}

public struct GraphQLVariable {
  let name: String
  
  public init(_ name: String) {
    self.name = name
  }
}

extension GraphQLVariable: GraphQLInputValue {
}

extension JSONEncodable {
  public func evaluate(with variables: [String: JSONEncodable]?) throws -> Any {
    return jsonValue
  }
}

public typealias GraphQLMap = [String: JSONEncodable?]

extension Dictionary where Key == String, Value == JSONEncodable? {
  public var withNilValuesRemoved: Dictionary<String, JSONEncodable> {
    var filtered = Dictionary<String, JSONEncodable>(minimumCapacity: count)
    for (key, value) in self {
      if value != nil {
        filtered[key] = value
      }
    }
    return filtered
  }
}

public protocol GraphQLMapConvertible: JSONEncodable {
  var graphQLMap: GraphQLMap { get }
}

public extension GraphQLMapConvertible {
  var jsonValue: Any {
    return graphQLMap.withNilValuesRemoved.jsonValue
  }
}

public typealias GraphQLID = String

public protocol APISwiftGraphQLOperation: AnyObject {
  
  static var operationString: String { get }
  static var requestString: String { get }
  static var operationIdentifier: String? { get }
  
  var variables: GraphQLMap? { get }
  
  associatedtype Data: GraphQLSelectionSet
}

public extension APISwiftGraphQLOperation {
  static var requestString: String {
    return operationString
  }

  static var operationIdentifier: String? {
    return nil
  }

  var variables: GraphQLMap? {
    return nil
  }
}

public protocol GraphQLQuery: APISwiftGraphQLOperation {}

public protocol GraphQLMutation: APISwiftGraphQLOperation {}

public protocol GraphQLSubscription: APISwiftGraphQLOperation {}

public protocol GraphQLFragment: GraphQLSelectionSet {
  static var possibleTypes: [String] { get }
}

public typealias Snapshot = [String: Any?]

public protocol GraphQLSelectionSet: Decodable {
  static var selections: [GraphQLSelection] { get }
  
  var snapshot: Snapshot { get }
  init(snapshot: Snapshot)
}

extension GraphQLSelectionSet {
    public init(from decoder: Decoder) throws {
        if let jsonObject = try? APISwiftJSONValue(from: decoder) {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(jsonObject)
            let decodedDictionary = try JSONSerialization.jsonObject(with: jsonData, options: []) as! [String: Any]
            let optionalDictionary = decodedDictionary.mapValues { $0 as Any? }

            self.init(snapshot: optionalDictionary)
        } else {
            self.init(snapshot: [:])
        }
    }
}

enum APISwiftJSONValue: Codable {
    case array([APISwiftJSONValue])
    case boolean(Bool)
    case number(Double)
    case object([String: APISwiftJSONValue])
    case string(String)
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let value = try? container.decode([String: APISwiftJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([APISwiftJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            self = .null
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .array(let value):
            try container.encode(value)
        case .boolean(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

public protocol GraphQLSelection {
}

public struct GraphQLField: GraphQLSelection {
  let name: String
  let alias: String?
  let arguments: [String: GraphQLInputValue]?
  
  var responseKey: String {
    return alias ?? name
  }
  
  let type: GraphQLOutputType
  
  public init(_ name: String, alias: String? = nil, arguments: [String: GraphQLInputValue]? = nil, type: GraphQLOutputType) {
    self.name = name
    self.alias = alias
    
    self.arguments = arguments
    
    self.type = type
  }
}

public indirect enum GraphQLOutputType {
  case scalar(JSONDecodable.Type)
  case object([GraphQLSelection])
  case nonNull(GraphQLOutputType)
  case list(GraphQLOutputType)
  
  var namedType: GraphQLOutputType {
    switch self {
    case .nonNull(let innerType), .list(let innerType):
      return innerType.namedType
    case .scalar, .object:
      return self
    }
  }
}

public struct GraphQLBooleanCondition: GraphQLSelection {
  let variableName: String
  let inverted: Bool
  let selections: [GraphQLSelection]
  
  public init(variableName: String, inverted: Bool, selections: [GraphQLSelection]) {
    self.variableName = variableName
    self.inverted = inverted;
    self.selections = selections;
  }
}

public struct GraphQLTypeCondition: GraphQLSelection {
  let possibleTypes: [String]
  let selections: [GraphQLSelection]
  
  public init(possibleTypes: [String], selections: [GraphQLSelection]) {
    self.possibleTypes = possibleTypes
    self.selections = selections;
  }
}

public struct GraphQLFragmentSpread: GraphQLSelection {
  let fragment: GraphQLFragment.Type
  
  public init(_ fragment: GraphQLFragment.Type) {
    self.fragment = fragment
  }
}

public struct GraphQLTypeCase: GraphQLSelection {
  let variants: [String: [GraphQLSelection]]
  let `default`: [GraphQLSelection]
  
  public init(variants: [String: [GraphQLSelection]], default: [GraphQLSelection]) {
    self.variants = variants
    self.default = `default`;
  }
}

public typealias JSONObject = [String: Any]

public protocol JSONDecodable {
  init(jsonValue value: Any) throws
}

public protocol JSONEncodable: GraphQLInputValue {
  var jsonValue: Any { get }
}

public enum JSONDecodingError: Error, LocalizedError {
  case missingValue
  case nullValue
  case wrongType
  case couldNotConvert(value: Any, to: Any.Type)
  
  public var errorDescription: String? {
    switch self {
    case .missingValue:
      return "Missing value"
    case .nullValue:
      return "Unexpected null value"
    case .wrongType:
      return "Wrong type"
    case .couldNotConvert(let value, let expectedType):
      return "Could not convert \"\(value)\" to \(expectedType)"
    }
  }
}

extension String: JSONDecodable, JSONEncodable {
  public init(jsonValue value: Any) throws {
    guard let string = value as? String else {
      throw JSONDecodingError.couldNotConvert(value: value, to: String.self)
    }
    self = string
  }

  public var jsonValue: Any {
    return self
  }
}

extension Int: JSONDecodable, JSONEncodable {
  public init(jsonValue value: Any) throws {
    guard let number = value as? NSNumber else {
      throw JSONDecodingError.couldNotConvert(value: value, to: Int.self)
    }
    self = number.intValue
  }

  public var jsonValue: Any {
    return self
  }
}

extension Float: JSONDecodable, JSONEncodable {
  public init(jsonValue value: Any) throws {
    guard let number = value as? NSNumber else {
      throw JSONDecodingError.couldNotConvert(value: value, to: Float.self)
    }
    self = number.floatValue
  }

  public var jsonValue: Any {
    return self
  }
}

extension Double: JSONDecodable, JSONEncodable {
  public init(jsonValue value: Any) throws {
    guard let number = value as? NSNumber else {
      throw JSONDecodingError.couldNotConvert(value: value, to: Double.self)
    }
    self = number.doubleValue
  }

  public var jsonValue: Any {
    return self
  }
}

extension Bool: JSONDecodable, JSONEncodable {
  public init(jsonValue value: Any) throws {
    guard let bool = value as? Bool else {
        throw JSONDecodingError.couldNotConvert(value: value, to: Bool.self)
    }
    self = bool
  }

  public var jsonValue: Any {
    return self
  }
}

extension RawRepresentable where RawValue: JSONDecodable {
  public init(jsonValue value: Any) throws {
    let rawValue = try RawValue(jsonValue: value)
    if let tempSelf = Self(rawValue: rawValue) {
      self = tempSelf
    } else {
      throw JSONDecodingError.couldNotConvert(value: value, to: Self.self)
    }
  }
}

extension RawRepresentable where RawValue: JSONEncodable {
  public var jsonValue: Any {
    return rawValue.jsonValue
  }
}

extension Optional where Wrapped: JSONDecodable {
  public init(jsonValue value: Any) throws {
    if value is NSNull {
      self = .none
    } else {
      self = .some(try Wrapped(jsonValue: value))
    }
  }
}

extension Optional: JSONEncodable {
  public var jsonValue: Any {
    switch self {
    case .none:
      return NSNull()
    case .some(let wrapped as JSONEncodable):
      return wrapped.jsonValue
    default:
      fatalError("Optional is only JSONEncodable if Wrapped is")
    }
  }
}

extension Dictionary: JSONEncodable {
  public var jsonValue: Any {
    return jsonObject
  }
  
  public var jsonObject: JSONObject {
    var jsonObject = JSONObject(minimumCapacity: count)
    for (key, value) in self {
      if case let (key as String, value as JSONEncodable) = (key, value) {
        jsonObject[key] = value.jsonValue
      } else {
        fatalError("Dictionary is only JSONEncodable if Value is (and if Key is String)")
      }
    }
    return jsonObject
  }
}

extension Array: JSONEncodable {
  public var jsonValue: Any {
    return map() { element -> (Any) in
      if case let element as JSONEncodable = element {
        return element.jsonValue
      } else {
        fatalError("Array is only JSONEncodable if Element is")
      }
    }
  }
}

extension URL: JSONDecodable, JSONEncodable {
  public init(jsonValue value: Any) throws {
    guard let string = value as? String else {
      throw JSONDecodingError.couldNotConvert(value: value, to: URL.self)
    }
    self.init(string: string)!
  }

  public var jsonValue: Any {
    return self.absoluteString
  }
}

extension Dictionary {
  static func += (lhs: inout Dictionary, rhs: Dictionary) {
    lhs.merge(rhs) { (_, new) in new }
  }
}

#elseif canImport(AWSAppSync)
import AWSAppSync
#endif

public struct OvertimeNotificationInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(orgId: String, recipients: [String], title: String, body: String, category: NotificationCategory, postingId: GraphQLID? = nil, metadata: String? = nil) {
    graphQLMap = ["orgId": orgId, "recipients": recipients, "title": title, "body": body, "category": category, "postingId": postingId, "metadata": metadata]
  }

  public var orgId: String {
    get {
      return graphQLMap["orgId"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var recipients: [String] {
    get {
      return graphQLMap["recipients"] as! [String]
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "recipients")
    }
  }

  public var title: String {
    get {
      return graphQLMap["title"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "title")
    }
  }

  public var body: String {
    get {
      return graphQLMap["body"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "body")
    }
  }

  public var category: NotificationCategory {
    get {
      return graphQLMap["category"] as! NotificationCategory
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "category")
    }
  }

  public var postingId: GraphQLID? {
    get {
      return graphQLMap["postingId"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "postingId")
    }
  }

  public var metadata: String? {
    get {
      return graphQLMap["metadata"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "metadata")
    }
  }
}

public enum NotificationCategory: RawRepresentable, Equatable, JSONDecodable, JSONEncodable {
  public typealias RawValue = String
  case overtimePosted
  case overtimeEscalation
  case overtimeForceAssign
  case squadAlert
  case taskAlert
  case bulletin
  /// Auto generated constant for unknown enum values
  case unknown(RawValue)

  public init?(rawValue: RawValue) {
    switch rawValue {
      case "OVERTIME_POSTED": self = .overtimePosted
      case "OVERTIME_ESCALATION": self = .overtimeEscalation
      case "OVERTIME_FORCE_ASSIGN": self = .overtimeForceAssign
      case "SQUAD_ALERT": self = .squadAlert
      case "TASK_ALERT": self = .taskAlert
      case "BULLETIN": self = .bulletin
      default: self = .unknown(rawValue)
    }
  }

  public var rawValue: RawValue {
    switch self {
      case .overtimePosted: return "OVERTIME_POSTED"
      case .overtimeEscalation: return "OVERTIME_ESCALATION"
      case .overtimeForceAssign: return "OVERTIME_FORCE_ASSIGN"
      case .squadAlert: return "SQUAD_ALERT"
      case .taskAlert: return "TASK_ALERT"
      case .bulletin: return "BULLETIN"
      case .unknown(let value): return value
    }
  }

  public static func == (lhs: NotificationCategory, rhs: NotificationCategory) -> Bool {
    switch (lhs, rhs) {
      case (.overtimePosted, .overtimePosted): return true
      case (.overtimeEscalation, .overtimeEscalation): return true
      case (.overtimeForceAssign, .overtimeForceAssign): return true
      case (.squadAlert, .squadAlert): return true
      case (.taskAlert, .taskAlert): return true
      case (.bulletin, .bulletin): return true
      case (.unknown(let lhsValue), .unknown(let rhsValue)): return lhsValue == rhsValue
      default: return false
    }
  }
}

public struct CreateRosterEntryInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID? = nil, orgId: String, badgeNumber: String, shift: String? = nil, startsAt: String, endsAt: String, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "badgeNumber": badgeNumber, "shift": shift, "startsAt": startsAt, "endsAt": endsAt, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt]
  }

  public var id: GraphQLID? {
    get {
      return graphQLMap["id"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: String {
    get {
      return graphQLMap["orgId"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var badgeNumber: String {
    get {
      return graphQLMap["badgeNumber"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "badgeNumber")
    }
  }

  public var shift: String? {
    get {
      return graphQLMap["shift"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "shift")
    }
  }

  public var startsAt: String {
    get {
      return graphQLMap["startsAt"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "startsAt")
    }
  }

  public var endsAt: String {
    get {
      return graphQLMap["endsAt"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "endsAt")
    }
  }

  public var notes: String? {
    get {
      return graphQLMap["notes"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "notes")
    }
  }

  public var createdAt: String? {
    get {
      return graphQLMap["createdAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: String? {
    get {
      return graphQLMap["updatedAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }
}

public struct ModelRosterEntryConditionInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(orgId: ModelStringInput? = nil, badgeNumber: ModelStringInput? = nil, shift: ModelStringInput? = nil, startsAt: ModelStringInput? = nil, endsAt: ModelStringInput? = nil, notes: ModelStringInput? = nil, createdAt: ModelStringInput? = nil, updatedAt: ModelStringInput? = nil, and: [ModelRosterEntryConditionInput?]? = nil, or: [ModelRosterEntryConditionInput?]? = nil, not: ModelRosterEntryConditionInput? = nil) {
    graphQLMap = ["orgId": orgId, "badgeNumber": badgeNumber, "shift": shift, "startsAt": startsAt, "endsAt": endsAt, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "not": not]
  }

  public var orgId: ModelStringInput? {
    get {
      return graphQLMap["orgId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var badgeNumber: ModelStringInput? {
    get {
      return graphQLMap["badgeNumber"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "badgeNumber")
    }
  }

  public var shift: ModelStringInput? {
    get {
      return graphQLMap["shift"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "shift")
    }
  }

  public var startsAt: ModelStringInput? {
    get {
      return graphQLMap["startsAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "startsAt")
    }
  }

  public var endsAt: ModelStringInput? {
    get {
      return graphQLMap["endsAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "endsAt")
    }
  }

  public var notes: ModelStringInput? {
    get {
      return graphQLMap["notes"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "notes")
    }
  }

  public var createdAt: ModelStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelRosterEntryConditionInput?]? {
    get {
      return graphQLMap["and"] as! [ModelRosterEntryConditionInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelRosterEntryConditionInput?]? {
    get {
      return graphQLMap["or"] as! [ModelRosterEntryConditionInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var not: ModelRosterEntryConditionInput? {
    get {
      return graphQLMap["not"] as! ModelRosterEntryConditionInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "not")
    }
  }
}

public struct ModelStringInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(ne: String? = nil, eq: String? = nil, le: String? = nil, lt: String? = nil, ge: String? = nil, gt: String? = nil, contains: String? = nil, notContains: String? = nil, between: [String?]? = nil, beginsWith: String? = nil, attributeExists: Bool? = nil, attributeType: ModelAttributeTypes? = nil, size: ModelSizeInput? = nil) {
    graphQLMap = ["ne": ne, "eq": eq, "le": le, "lt": lt, "ge": ge, "gt": gt, "contains": contains, "notContains": notContains, "between": between, "beginsWith": beginsWith, "attributeExists": attributeExists, "attributeType": attributeType, "size": size]
  }

  public var ne: String? {
    get {
      return graphQLMap["ne"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ne")
    }
  }

  public var eq: String? {
    get {
      return graphQLMap["eq"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "eq")
    }
  }

  public var le: String? {
    get {
      return graphQLMap["le"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "le")
    }
  }

  public var lt: String? {
    get {
      return graphQLMap["lt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "lt")
    }
  }

  public var ge: String? {
    get {
      return graphQLMap["ge"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ge")
    }
  }

  public var gt: String? {
    get {
      return graphQLMap["gt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "gt")
    }
  }

  public var contains: String? {
    get {
      return graphQLMap["contains"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "contains")
    }
  }

  public var notContains: String? {
    get {
      return graphQLMap["notContains"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "notContains")
    }
  }

  public var between: [String?]? {
    get {
      return graphQLMap["between"] as! [String?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "between")
    }
  }

  public var beginsWith: String? {
    get {
      return graphQLMap["beginsWith"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "beginsWith")
    }
  }

  public var attributeExists: Bool? {
    get {
      return graphQLMap["attributeExists"] as! Bool?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "attributeExists")
    }
  }

  public var attributeType: ModelAttributeTypes? {
    get {
      return graphQLMap["attributeType"] as! ModelAttributeTypes?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "attributeType")
    }
  }

  public var size: ModelSizeInput? {
    get {
      return graphQLMap["size"] as! ModelSizeInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "size")
    }
  }
}

public enum ModelAttributeTypes: RawRepresentable, Equatable, JSONDecodable, JSONEncodable {
  public typealias RawValue = String
  case binary
  case binarySet
  case bool
  case list
  case map
  case number
  case numberSet
  case string
  case stringSet
  case null
  /// Auto generated constant for unknown enum values
  case unknown(RawValue)

  public init?(rawValue: RawValue) {
    switch rawValue {
      case "binary": self = .binary
      case "binarySet": self = .binarySet
      case "bool": self = .bool
      case "list": self = .list
      case "map": self = .map
      case "number": self = .number
      case "numberSet": self = .numberSet
      case "string": self = .string
      case "stringSet": self = .stringSet
      case "_null": self = .null
      default: self = .unknown(rawValue)
    }
  }

  public var rawValue: RawValue {
    switch self {
      case .binary: return "binary"
      case .binarySet: return "binarySet"
      case .bool: return "bool"
      case .list: return "list"
      case .map: return "map"
      case .number: return "number"
      case .numberSet: return "numberSet"
      case .string: return "string"
      case .stringSet: return "stringSet"
      case .null: return "_null"
      case .unknown(let value): return value
    }
  }

  public static func == (lhs: ModelAttributeTypes, rhs: ModelAttributeTypes) -> Bool {
    switch (lhs, rhs) {
      case (.binary, .binary): return true
      case (.binarySet, .binarySet): return true
      case (.bool, .bool): return true
      case (.list, .list): return true
      case (.map, .map): return true
      case (.number, .number): return true
      case (.numberSet, .numberSet): return true
      case (.string, .string): return true
      case (.stringSet, .stringSet): return true
      case (.null, .null): return true
      case (.unknown(let lhsValue), .unknown(let rhsValue)): return lhsValue == rhsValue
      default: return false
    }
  }
}

public struct ModelSizeInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(ne: Int? = nil, eq: Int? = nil, le: Int? = nil, lt: Int? = nil, ge: Int? = nil, gt: Int? = nil, between: [Int?]? = nil) {
    graphQLMap = ["ne": ne, "eq": eq, "le": le, "lt": lt, "ge": ge, "gt": gt, "between": between]
  }

  public var ne: Int? {
    get {
      return graphQLMap["ne"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ne")
    }
  }

  public var eq: Int? {
    get {
      return graphQLMap["eq"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "eq")
    }
  }

  public var le: Int? {
    get {
      return graphQLMap["le"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "le")
    }
  }

  public var lt: Int? {
    get {
      return graphQLMap["lt"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "lt")
    }
  }

  public var ge: Int? {
    get {
      return graphQLMap["ge"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ge")
    }
  }

  public var gt: Int? {
    get {
      return graphQLMap["gt"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "gt")
    }
  }

  public var between: [Int?]? {
    get {
      return graphQLMap["between"] as! [Int?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "between")
    }
  }
}

public struct UpdateRosterEntryInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID, orgId: String? = nil, badgeNumber: String? = nil, shift: String? = nil, startsAt: String? = nil, endsAt: String? = nil, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "badgeNumber": badgeNumber, "shift": shift, "startsAt": startsAt, "endsAt": endsAt, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt]
  }

  public var id: GraphQLID {
    get {
      return graphQLMap["id"] as! GraphQLID
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: String? {
    get {
      return graphQLMap["orgId"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var badgeNumber: String? {
    get {
      return graphQLMap["badgeNumber"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "badgeNumber")
    }
  }

  public var shift: String? {
    get {
      return graphQLMap["shift"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "shift")
    }
  }

  public var startsAt: String? {
    get {
      return graphQLMap["startsAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "startsAt")
    }
  }

  public var endsAt: String? {
    get {
      return graphQLMap["endsAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "endsAt")
    }
  }

  public var notes: String? {
    get {
      return graphQLMap["notes"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "notes")
    }
  }

  public var createdAt: String? {
    get {
      return graphQLMap["createdAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: String? {
    get {
      return graphQLMap["updatedAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }
}

public struct DeleteRosterEntryInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID) {
    graphQLMap = ["id": id]
  }

  public var id: GraphQLID {
    get {
      return graphQLMap["id"] as! GraphQLID
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }
}

public struct CreateVehicleInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID? = nil, orgId: String, callsign: String, make: String? = nil, model: String? = nil, plate: String? = nil, inService: Bool? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "callsign": callsign, "make": make, "model": model, "plate": plate, "inService": inService, "createdAt": createdAt, "updatedAt": updatedAt]
  }

  public var id: GraphQLID? {
    get {
      return graphQLMap["id"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: String {
    get {
      return graphQLMap["orgId"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var callsign: String {
    get {
      return graphQLMap["callsign"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "callsign")
    }
  }

  public var make: String? {
    get {
      return graphQLMap["make"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "make")
    }
  }

  public var model: String? {
    get {
      return graphQLMap["model"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "model")
    }
  }

  public var plate: String? {
    get {
      return graphQLMap["plate"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "plate")
    }
  }

  public var inService: Bool? {
    get {
      return graphQLMap["inService"] as! Bool?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "inService")
    }
  }

  public var createdAt: String? {
    get {
      return graphQLMap["createdAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: String? {
    get {
      return graphQLMap["updatedAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }
}

public struct ModelVehicleConditionInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(orgId: ModelStringInput? = nil, callsign: ModelStringInput? = nil, make: ModelStringInput? = nil, model: ModelStringInput? = nil, plate: ModelStringInput? = nil, inService: ModelBooleanInput? = nil, createdAt: ModelStringInput? = nil, updatedAt: ModelStringInput? = nil, and: [ModelVehicleConditionInput?]? = nil, or: [ModelVehicleConditionInput?]? = nil, not: ModelVehicleConditionInput? = nil) {
    graphQLMap = ["orgId": orgId, "callsign": callsign, "make": make, "model": model, "plate": plate, "inService": inService, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "not": not]
  }

  public var orgId: ModelStringInput? {
    get {
      return graphQLMap["orgId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var callsign: ModelStringInput? {
    get {
      return graphQLMap["callsign"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "callsign")
    }
  }

  public var make: ModelStringInput? {
    get {
      return graphQLMap["make"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "make")
    }
  }

  public var model: ModelStringInput? {
    get {
      return graphQLMap["model"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "model")
    }
  }

  public var plate: ModelStringInput? {
    get {
      return graphQLMap["plate"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "plate")
    }
  }

  public var inService: ModelBooleanInput? {
    get {
      return graphQLMap["inService"] as! ModelBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "inService")
    }
  }

  public var createdAt: ModelStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelVehicleConditionInput?]? {
    get {
      return graphQLMap["and"] as! [ModelVehicleConditionInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelVehicleConditionInput?]? {
    get {
      return graphQLMap["or"] as! [ModelVehicleConditionInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var not: ModelVehicleConditionInput? {
    get {
      return graphQLMap["not"] as! ModelVehicleConditionInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "not")
    }
  }
}

public struct ModelBooleanInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(ne: Bool? = nil, eq: Bool? = nil, attributeExists: Bool? = nil, attributeType: ModelAttributeTypes? = nil) {
    graphQLMap = ["ne": ne, "eq": eq, "attributeExists": attributeExists, "attributeType": attributeType]
  }

  public var ne: Bool? {
    get {
      return graphQLMap["ne"] as! Bool?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ne")
    }
  }

  public var eq: Bool? {
    get {
      return graphQLMap["eq"] as! Bool?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "eq")
    }
  }

  public var attributeExists: Bool? {
    get {
      return graphQLMap["attributeExists"] as! Bool?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "attributeExists")
    }
  }

  public var attributeType: ModelAttributeTypes? {
    get {
      return graphQLMap["attributeType"] as! ModelAttributeTypes?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "attributeType")
    }
  }
}

public struct UpdateVehicleInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID, orgId: String? = nil, callsign: String? = nil, make: String? = nil, model: String? = nil, plate: String? = nil, inService: Bool? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "callsign": callsign, "make": make, "model": model, "plate": plate, "inService": inService, "createdAt": createdAt, "updatedAt": updatedAt]
  }

  public var id: GraphQLID {
    get {
      return graphQLMap["id"] as! GraphQLID
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: String? {
    get {
      return graphQLMap["orgId"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var callsign: String? {
    get {
      return graphQLMap["callsign"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "callsign")
    }
  }

  public var make: String? {
    get {
      return graphQLMap["make"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "make")
    }
  }

  public var model: String? {
    get {
      return graphQLMap["model"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "model")
    }
  }

  public var plate: String? {
    get {
      return graphQLMap["plate"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "plate")
    }
  }

  public var inService: Bool? {
    get {
      return graphQLMap["inService"] as! Bool?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "inService")
    }
  }

  public var createdAt: String? {
    get {
      return graphQLMap["createdAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: String? {
    get {
      return graphQLMap["updatedAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }
}

public struct DeleteVehicleInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID) {
    graphQLMap = ["id": id]
  }

  public var id: GraphQLID {
    get {
      return graphQLMap["id"] as! GraphQLID
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }
}

public struct CreateCalendarEventInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID? = nil, orgId: String, ownerId: String, title: String, category: String, color: String, notes: String? = nil, startsAt: String, endsAt: String, reminderMinutesBefore: Int? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "ownerId": ownerId, "title": title, "category": category, "color": color, "notes": notes, "startsAt": startsAt, "endsAt": endsAt, "reminderMinutesBefore": reminderMinutesBefore, "createdAt": createdAt, "updatedAt": updatedAt]
  }

  public var id: GraphQLID? {
    get {
      return graphQLMap["id"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: String {
    get {
      return graphQLMap["orgId"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var ownerId: String {
    get {
      return graphQLMap["ownerId"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ownerId")
    }
  }

  public var title: String {
    get {
      return graphQLMap["title"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "title")
    }
  }

  public var category: String {
    get {
      return graphQLMap["category"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "category")
    }
  }

  public var color: String {
    get {
      return graphQLMap["color"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "color")
    }
  }

  public var notes: String? {
    get {
      return graphQLMap["notes"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "notes")
    }
  }

  public var startsAt: String {
    get {
      return graphQLMap["startsAt"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "startsAt")
    }
  }

  public var endsAt: String {
    get {
      return graphQLMap["endsAt"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "endsAt")
    }
  }

  public var reminderMinutesBefore: Int? {
    get {
      return graphQLMap["reminderMinutesBefore"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "reminderMinutesBefore")
    }
  }

  public var createdAt: String? {
    get {
      return graphQLMap["createdAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: String? {
    get {
      return graphQLMap["updatedAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }
}

public struct ModelCalendarEventConditionInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(orgId: ModelStringInput? = nil, ownerId: ModelStringInput? = nil, title: ModelStringInput? = nil, category: ModelStringInput? = nil, color: ModelStringInput? = nil, notes: ModelStringInput? = nil, startsAt: ModelStringInput? = nil, endsAt: ModelStringInput? = nil, reminderMinutesBefore: ModelIntInput? = nil, createdAt: ModelStringInput? = nil, updatedAt: ModelStringInput? = nil, and: [ModelCalendarEventConditionInput?]? = nil, or: [ModelCalendarEventConditionInput?]? = nil, not: ModelCalendarEventConditionInput? = nil) {
    graphQLMap = ["orgId": orgId, "ownerId": ownerId, "title": title, "category": category, "color": color, "notes": notes, "startsAt": startsAt, "endsAt": endsAt, "reminderMinutesBefore": reminderMinutesBefore, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "not": not]
  }

  public var orgId: ModelStringInput? {
    get {
      return graphQLMap["orgId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var ownerId: ModelStringInput? {
    get {
      return graphQLMap["ownerId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ownerId")
    }
  }

  public var title: ModelStringInput? {
    get {
      return graphQLMap["title"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "title")
    }
  }

  public var category: ModelStringInput? {
    get {
      return graphQLMap["category"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "category")
    }
  }

  public var color: ModelStringInput? {
    get {
      return graphQLMap["color"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "color")
    }
  }

  public var notes: ModelStringInput? {
    get {
      return graphQLMap["notes"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "notes")
    }
  }

  public var startsAt: ModelStringInput? {
    get {
      return graphQLMap["startsAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "startsAt")
    }
  }

  public var endsAt: ModelStringInput? {
    get {
      return graphQLMap["endsAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "endsAt")
    }
  }

  public var reminderMinutesBefore: ModelIntInput? {
    get {
      return graphQLMap["reminderMinutesBefore"] as! ModelIntInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "reminderMinutesBefore")
    }
  }

  public var createdAt: ModelStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelCalendarEventConditionInput?]? {
    get {
      return graphQLMap["and"] as! [ModelCalendarEventConditionInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelCalendarEventConditionInput?]? {
    get {
      return graphQLMap["or"] as! [ModelCalendarEventConditionInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var not: ModelCalendarEventConditionInput? {
    get {
      return graphQLMap["not"] as! ModelCalendarEventConditionInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "not")
    }
  }
}

public struct ModelIntInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(ne: Int? = nil, eq: Int? = nil, le: Int? = nil, lt: Int? = nil, ge: Int? = nil, gt: Int? = nil, between: [Int?]? = nil, attributeExists: Bool? = nil, attributeType: ModelAttributeTypes? = nil) {
    graphQLMap = ["ne": ne, "eq": eq, "le": le, "lt": lt, "ge": ge, "gt": gt, "between": between, "attributeExists": attributeExists, "attributeType": attributeType]
  }

  public var ne: Int? {
    get {
      return graphQLMap["ne"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ne")
    }
  }

  public var eq: Int? {
    get {
      return graphQLMap["eq"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "eq")
    }
  }

  public var le: Int? {
    get {
      return graphQLMap["le"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "le")
    }
  }

  public var lt: Int? {
    get {
      return graphQLMap["lt"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "lt")
    }
  }

  public var ge: Int? {
    get {
      return graphQLMap["ge"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ge")
    }
  }

  public var gt: Int? {
    get {
      return graphQLMap["gt"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "gt")
    }
  }

  public var between: [Int?]? {
    get {
      return graphQLMap["between"] as! [Int?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "between")
    }
  }

  public var attributeExists: Bool? {
    get {
      return graphQLMap["attributeExists"] as! Bool?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "attributeExists")
    }
  }

  public var attributeType: ModelAttributeTypes? {
    get {
      return graphQLMap["attributeType"] as! ModelAttributeTypes?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "attributeType")
    }
  }
}

public struct UpdateCalendarEventInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID, orgId: String? = nil, ownerId: String? = nil, title: String? = nil, category: String? = nil, color: String? = nil, notes: String? = nil, startsAt: String? = nil, endsAt: String? = nil, reminderMinutesBefore: Int? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "ownerId": ownerId, "title": title, "category": category, "color": color, "notes": notes, "startsAt": startsAt, "endsAt": endsAt, "reminderMinutesBefore": reminderMinutesBefore, "createdAt": createdAt, "updatedAt": updatedAt]
  }

  public var id: GraphQLID {
    get {
      return graphQLMap["id"] as! GraphQLID
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: String? {
    get {
      return graphQLMap["orgId"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var ownerId: String? {
    get {
      return graphQLMap["ownerId"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ownerId")
    }
  }

  public var title: String? {
    get {
      return graphQLMap["title"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "title")
    }
  }

  public var category: String? {
    get {
      return graphQLMap["category"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "category")
    }
  }

  public var color: String? {
    get {
      return graphQLMap["color"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "color")
    }
  }

  public var notes: String? {
    get {
      return graphQLMap["notes"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "notes")
    }
  }

  public var startsAt: String? {
    get {
      return graphQLMap["startsAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "startsAt")
    }
  }

  public var endsAt: String? {
    get {
      return graphQLMap["endsAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "endsAt")
    }
  }

  public var reminderMinutesBefore: Int? {
    get {
      return graphQLMap["reminderMinutesBefore"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "reminderMinutesBefore")
    }
  }

  public var createdAt: String? {
    get {
      return graphQLMap["createdAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: String? {
    get {
      return graphQLMap["updatedAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }
}

public struct DeleteCalendarEventInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID) {
    graphQLMap = ["id": id]
  }

  public var id: GraphQLID {
    get {
      return graphQLMap["id"] as! GraphQLID
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }
}

public struct CreateOfficerAssignmentInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID? = nil, orgId: String, badgeNumber: String, title: String, detail: String? = nil, location: String? = nil, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "badgeNumber": badgeNumber, "title": title, "detail": detail, "location": location, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt]
  }

  public var id: GraphQLID? {
    get {
      return graphQLMap["id"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: String {
    get {
      return graphQLMap["orgId"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var badgeNumber: String {
    get {
      return graphQLMap["badgeNumber"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "badgeNumber")
    }
  }

  public var title: String {
    get {
      return graphQLMap["title"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "title")
    }
  }

  public var detail: String? {
    get {
      return graphQLMap["detail"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "detail")
    }
  }

  public var location: String? {
    get {
      return graphQLMap["location"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "location")
    }
  }

  public var notes: String? {
    get {
      return graphQLMap["notes"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "notes")
    }
  }

  public var createdAt: String? {
    get {
      return graphQLMap["createdAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: String? {
    get {
      return graphQLMap["updatedAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }
}

public struct ModelOfficerAssignmentConditionInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(orgId: ModelStringInput? = nil, badgeNumber: ModelStringInput? = nil, title: ModelStringInput? = nil, detail: ModelStringInput? = nil, location: ModelStringInput? = nil, notes: ModelStringInput? = nil, createdAt: ModelStringInput? = nil, updatedAt: ModelStringInput? = nil, and: [ModelOfficerAssignmentConditionInput?]? = nil, or: [ModelOfficerAssignmentConditionInput?]? = nil, not: ModelOfficerAssignmentConditionInput? = nil) {
    graphQLMap = ["orgId": orgId, "badgeNumber": badgeNumber, "title": title, "detail": detail, "location": location, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "not": not]
  }

  public var orgId: ModelStringInput? {
    get {
      return graphQLMap["orgId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var badgeNumber: ModelStringInput? {
    get {
      return graphQLMap["badgeNumber"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "badgeNumber")
    }
  }

  public var title: ModelStringInput? {
    get {
      return graphQLMap["title"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "title")
    }
  }

  public var detail: ModelStringInput? {
    get {
      return graphQLMap["detail"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "detail")
    }
  }

  public var location: ModelStringInput? {
    get {
      return graphQLMap["location"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "location")
    }
  }

  public var notes: ModelStringInput? {
    get {
      return graphQLMap["notes"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "notes")
    }
  }

  public var createdAt: ModelStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelOfficerAssignmentConditionInput?]? {
    get {
      return graphQLMap["and"] as! [ModelOfficerAssignmentConditionInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelOfficerAssignmentConditionInput?]? {
    get {
      return graphQLMap["or"] as! [ModelOfficerAssignmentConditionInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var not: ModelOfficerAssignmentConditionInput? {
    get {
      return graphQLMap["not"] as! ModelOfficerAssignmentConditionInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "not")
    }
  }
}

public struct UpdateOfficerAssignmentInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID, orgId: String? = nil, badgeNumber: String? = nil, title: String? = nil, detail: String? = nil, location: String? = nil, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "badgeNumber": badgeNumber, "title": title, "detail": detail, "location": location, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt]
  }

  public var id: GraphQLID {
    get {
      return graphQLMap["id"] as! GraphQLID
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: String? {
    get {
      return graphQLMap["orgId"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var badgeNumber: String? {
    get {
      return graphQLMap["badgeNumber"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "badgeNumber")
    }
  }

  public var title: String? {
    get {
      return graphQLMap["title"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "title")
    }
  }

  public var detail: String? {
    get {
      return graphQLMap["detail"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "detail")
    }
  }

  public var location: String? {
    get {
      return graphQLMap["location"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "location")
    }
  }

  public var notes: String? {
    get {
      return graphQLMap["notes"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "notes")
    }
  }

  public var createdAt: String? {
    get {
      return graphQLMap["createdAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: String? {
    get {
      return graphQLMap["updatedAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }
}

public struct DeleteOfficerAssignmentInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID) {
    graphQLMap = ["id": id]
  }

  public var id: GraphQLID {
    get {
      return graphQLMap["id"] as! GraphQLID
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }
}

public struct CreateOvertimePostingInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID? = nil, orgId: String, title: String, location: String? = nil, scenario: OvertimeScenario, startsAt: String, endsAt: String, slots: Int, policySnapshot: String, selectionPolicy: OvertimeSelectionPolicy? = nil, needsEscalation: Bool? = nil, state: OvertimePostingState, createdBy: String, createdAt: String? = nil, updatedAt: String? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "title": title, "location": location, "scenario": scenario, "startsAt": startsAt, "endsAt": endsAt, "slots": slots, "policySnapshot": policySnapshot, "selectionPolicy": selectionPolicy, "needsEscalation": needsEscalation, "state": state, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt]
  }

  public var id: GraphQLID? {
    get {
      return graphQLMap["id"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: String {
    get {
      return graphQLMap["orgId"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var title: String {
    get {
      return graphQLMap["title"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "title")
    }
  }

  public var location: String? {
    get {
      return graphQLMap["location"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "location")
    }
  }

  public var scenario: OvertimeScenario {
    get {
      return graphQLMap["scenario"] as! OvertimeScenario
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "scenario")
    }
  }

  public var startsAt: String {
    get {
      return graphQLMap["startsAt"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "startsAt")
    }
  }

  public var endsAt: String {
    get {
      return graphQLMap["endsAt"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "endsAt")
    }
  }

  public var slots: Int {
    get {
      return graphQLMap["slots"] as! Int
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "slots")
    }
  }

  public var policySnapshot: String {
    get {
      return graphQLMap["policySnapshot"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "policySnapshot")
    }
  }

  public var selectionPolicy: OvertimeSelectionPolicy? {
    get {
      return graphQLMap["selectionPolicy"] as! OvertimeSelectionPolicy?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "selectionPolicy")
    }
  }

  public var needsEscalation: Bool? {
    get {
      return graphQLMap["needsEscalation"] as! Bool?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "needsEscalation")
    }
  }

  public var state: OvertimePostingState {
    get {
      return graphQLMap["state"] as! OvertimePostingState
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "state")
    }
  }

  public var createdBy: String {
    get {
      return graphQLMap["createdBy"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdBy")
    }
  }

  public var createdAt: String? {
    get {
      return graphQLMap["createdAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: String? {
    get {
      return graphQLMap["updatedAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }
}

public enum OvertimeScenario: RawRepresentable, Equatable, JSONDecodable, JSONEncodable {
  public typealias RawValue = String
  case patrolShortShift
  case sergeantShortShift
  case specialEvent
  case otherOvertime
  /// Auto generated constant for unknown enum values
  case unknown(RawValue)

  public init?(rawValue: RawValue) {
    switch rawValue {
      case "PATROL_SHORT_SHIFT": self = .patrolShortShift
      case "SERGEANT_SHORT_SHIFT": self = .sergeantShortShift
      case "SPECIAL_EVENT": self = .specialEvent
      case "OTHER_OVERTIME": self = .otherOvertime
      default: self = .unknown(rawValue)
    }
  }

  public var rawValue: RawValue {
    switch self {
      case .patrolShortShift: return "PATROL_SHORT_SHIFT"
      case .sergeantShortShift: return "SERGEANT_SHORT_SHIFT"
      case .specialEvent: return "SPECIAL_EVENT"
      case .otherOvertime: return "OTHER_OVERTIME"
      case .unknown(let value): return value
    }
  }

  public static func == (lhs: OvertimeScenario, rhs: OvertimeScenario) -> Bool {
    switch (lhs, rhs) {
      case (.patrolShortShift, .patrolShortShift): return true
      case (.sergeantShortShift, .sergeantShortShift): return true
      case (.specialEvent, .specialEvent): return true
      case (.otherOvertime, .otherOvertime): return true
      case (.unknown(let lhsValue), .unknown(let rhsValue)): return lhsValue == rhsValue
      default: return false
    }
  }
}

public enum OvertimeSelectionPolicy: RawRepresentable, Equatable, JSONDecodable, JSONEncodable {
  public typealias RawValue = String
  case rotation
  case seniority
  case firstCome
  /// Auto generated constant for unknown enum values
  case unknown(RawValue)

  public init?(rawValue: RawValue) {
    switch rawValue {
      case "ROTATION": self = .rotation
      case "SENIORITY": self = .seniority
      case "FIRST_COME": self = .firstCome
      default: self = .unknown(rawValue)
    }
  }

  public var rawValue: RawValue {
    switch self {
      case .rotation: return "ROTATION"
      case .seniority: return "SENIORITY"
      case .firstCome: return "FIRST_COME"
      case .unknown(let value): return value
    }
  }

  public static func == (lhs: OvertimeSelectionPolicy, rhs: OvertimeSelectionPolicy) -> Bool {
    switch (lhs, rhs) {
      case (.rotation, .rotation): return true
      case (.seniority, .seniority): return true
      case (.firstCome, .firstCome): return true
      case (.unknown(let lhsValue), .unknown(let rhsValue)): return lhsValue == rhsValue
      default: return false
    }
  }
}

public enum OvertimePostingState: RawRepresentable, Equatable, JSONDecodable, JSONEncodable {
  public typealias RawValue = String
  case `open`
  case filled
  case closed
  /// Auto generated constant for unknown enum values
  case unknown(RawValue)

  public init?(rawValue: RawValue) {
    switch rawValue {
      case "OPEN": self = .open
      case "FILLED": self = .filled
      case "CLOSED": self = .closed
      default: self = .unknown(rawValue)
    }
  }

  public var rawValue: RawValue {
    switch self {
      case .open: return "OPEN"
      case .filled: return "FILLED"
      case .closed: return "CLOSED"
      case .unknown(let value): return value
    }
  }

  public static func == (lhs: OvertimePostingState, rhs: OvertimePostingState) -> Bool {
    switch (lhs, rhs) {
      case (.open, .open): return true
      case (.filled, .filled): return true
      case (.closed, .closed): return true
      case (.unknown(let lhsValue), .unknown(let rhsValue)): return lhsValue == rhsValue
      default: return false
    }
  }
}

public struct ModelOvertimePostingConditionInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(orgId: ModelStringInput? = nil, title: ModelStringInput? = nil, location: ModelStringInput? = nil, scenario: ModelOvertimeScenarioInput? = nil, startsAt: ModelStringInput? = nil, endsAt: ModelStringInput? = nil, slots: ModelIntInput? = nil, policySnapshot: ModelStringInput? = nil, selectionPolicy: ModelOvertimeSelectionPolicyInput? = nil, needsEscalation: ModelBooleanInput? = nil, state: ModelOvertimePostingStateInput? = nil, createdBy: ModelStringInput? = nil, createdAt: ModelStringInput? = nil, updatedAt: ModelStringInput? = nil, and: [ModelOvertimePostingConditionInput?]? = nil, or: [ModelOvertimePostingConditionInput?]? = nil, not: ModelOvertimePostingConditionInput? = nil) {
    graphQLMap = ["orgId": orgId, "title": title, "location": location, "scenario": scenario, "startsAt": startsAt, "endsAt": endsAt, "slots": slots, "policySnapshot": policySnapshot, "selectionPolicy": selectionPolicy, "needsEscalation": needsEscalation, "state": state, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "not": not]
  }

  public var orgId: ModelStringInput? {
    get {
      return graphQLMap["orgId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var title: ModelStringInput? {
    get {
      return graphQLMap["title"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "title")
    }
  }

  public var location: ModelStringInput? {
    get {
      return graphQLMap["location"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "location")
    }
  }

  public var scenario: ModelOvertimeScenarioInput? {
    get {
      return graphQLMap["scenario"] as! ModelOvertimeScenarioInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "scenario")
    }
  }

  public var startsAt: ModelStringInput? {
    get {
      return graphQLMap["startsAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "startsAt")
    }
  }

  public var endsAt: ModelStringInput? {
    get {
      return graphQLMap["endsAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "endsAt")
    }
  }

  public var slots: ModelIntInput? {
    get {
      return graphQLMap["slots"] as! ModelIntInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "slots")
    }
  }

  public var policySnapshot: ModelStringInput? {
    get {
      return graphQLMap["policySnapshot"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "policySnapshot")
    }
  }

  public var selectionPolicy: ModelOvertimeSelectionPolicyInput? {
    get {
      return graphQLMap["selectionPolicy"] as! ModelOvertimeSelectionPolicyInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "selectionPolicy")
    }
  }

  public var needsEscalation: ModelBooleanInput? {
    get {
      return graphQLMap["needsEscalation"] as! ModelBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "needsEscalation")
    }
  }

  public var state: ModelOvertimePostingStateInput? {
    get {
      return graphQLMap["state"] as! ModelOvertimePostingStateInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "state")
    }
  }

  public var createdBy: ModelStringInput? {
    get {
      return graphQLMap["createdBy"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdBy")
    }
  }

  public var createdAt: ModelStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelOvertimePostingConditionInput?]? {
    get {
      return graphQLMap["and"] as! [ModelOvertimePostingConditionInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelOvertimePostingConditionInput?]? {
    get {
      return graphQLMap["or"] as! [ModelOvertimePostingConditionInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var not: ModelOvertimePostingConditionInput? {
    get {
      return graphQLMap["not"] as! ModelOvertimePostingConditionInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "not")
    }
  }
}

public struct ModelOvertimeScenarioInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(eq: OvertimeScenario? = nil, ne: OvertimeScenario? = nil) {
    graphQLMap = ["eq": eq, "ne": ne]
  }

  public var eq: OvertimeScenario? {
    get {
      return graphQLMap["eq"] as! OvertimeScenario?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "eq")
    }
  }

  public var ne: OvertimeScenario? {
    get {
      return graphQLMap["ne"] as! OvertimeScenario?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ne")
    }
  }
}

public struct ModelOvertimeSelectionPolicyInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(eq: OvertimeSelectionPolicy? = nil, ne: OvertimeSelectionPolicy? = nil) {
    graphQLMap = ["eq": eq, "ne": ne]
  }

  public var eq: OvertimeSelectionPolicy? {
    get {
      return graphQLMap["eq"] as! OvertimeSelectionPolicy?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "eq")
    }
  }

  public var ne: OvertimeSelectionPolicy? {
    get {
      return graphQLMap["ne"] as! OvertimeSelectionPolicy?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ne")
    }
  }
}

public struct ModelOvertimePostingStateInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(eq: OvertimePostingState? = nil, ne: OvertimePostingState? = nil) {
    graphQLMap = ["eq": eq, "ne": ne]
  }

  public var eq: OvertimePostingState? {
    get {
      return graphQLMap["eq"] as! OvertimePostingState?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "eq")
    }
  }

  public var ne: OvertimePostingState? {
    get {
      return graphQLMap["ne"] as! OvertimePostingState?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ne")
    }
  }
}

public enum OvertimeInviteStatus: RawRepresentable, Equatable, JSONDecodable, JSONEncodable {
  public typealias RawValue = String
  case pending
  case accepted
  case declined
  case ordered
  case expired
  /// Auto generated constant for unknown enum values
  case unknown(RawValue)

  public init?(rawValue: RawValue) {
    switch rawValue {
      case "PENDING": self = .pending
      case "ACCEPTED": self = .accepted
      case "DECLINED": self = .declined
      case "ORDERED": self = .ordered
      case "EXPIRED": self = .expired
      default: self = .unknown(rawValue)
    }
  }

  public var rawValue: RawValue {
    switch self {
      case .pending: return "PENDING"
      case .accepted: return "ACCEPTED"
      case .declined: return "DECLINED"
      case .ordered: return "ORDERED"
      case .expired: return "EXPIRED"
      case .unknown(let value): return value
    }
  }

  public static func == (lhs: OvertimeInviteStatus, rhs: OvertimeInviteStatus) -> Bool {
    switch (lhs, rhs) {
      case (.pending, .pending): return true
      case (.accepted, .accepted): return true
      case (.declined, .declined): return true
      case (.ordered, .ordered): return true
      case (.expired, .expired): return true
      case (.unknown(let lhsValue), .unknown(let rhsValue)): return lhsValue == rhsValue
      default: return false
    }
  }
}

public struct UpdateOvertimePostingInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID, orgId: String? = nil, title: String? = nil, location: String? = nil, scenario: OvertimeScenario? = nil, startsAt: String? = nil, endsAt: String? = nil, slots: Int? = nil, policySnapshot: String? = nil, selectionPolicy: OvertimeSelectionPolicy? = nil, needsEscalation: Bool? = nil, state: OvertimePostingState? = nil, createdBy: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "title": title, "location": location, "scenario": scenario, "startsAt": startsAt, "endsAt": endsAt, "slots": slots, "policySnapshot": policySnapshot, "selectionPolicy": selectionPolicy, "needsEscalation": needsEscalation, "state": state, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt]
  }

  public var id: GraphQLID {
    get {
      return graphQLMap["id"] as! GraphQLID
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: String? {
    get {
      return graphQLMap["orgId"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var title: String? {
    get {
      return graphQLMap["title"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "title")
    }
  }

  public var location: String? {
    get {
      return graphQLMap["location"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "location")
    }
  }

  public var scenario: OvertimeScenario? {
    get {
      return graphQLMap["scenario"] as! OvertimeScenario?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "scenario")
    }
  }

  public var startsAt: String? {
    get {
      return graphQLMap["startsAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "startsAt")
    }
  }

  public var endsAt: String? {
    get {
      return graphQLMap["endsAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "endsAt")
    }
  }

  public var slots: Int? {
    get {
      return graphQLMap["slots"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "slots")
    }
  }

  public var policySnapshot: String? {
    get {
      return graphQLMap["policySnapshot"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "policySnapshot")
    }
  }

  public var selectionPolicy: OvertimeSelectionPolicy? {
    get {
      return graphQLMap["selectionPolicy"] as! OvertimeSelectionPolicy?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "selectionPolicy")
    }
  }

  public var needsEscalation: Bool? {
    get {
      return graphQLMap["needsEscalation"] as! Bool?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "needsEscalation")
    }
  }

  public var state: OvertimePostingState? {
    get {
      return graphQLMap["state"] as! OvertimePostingState?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "state")
    }
  }

  public var createdBy: String? {
    get {
      return graphQLMap["createdBy"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdBy")
    }
  }

  public var createdAt: String? {
    get {
      return graphQLMap["createdAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: String? {
    get {
      return graphQLMap["updatedAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }
}

public struct DeleteOvertimePostingInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID) {
    graphQLMap = ["id": id]
  }

  public var id: GraphQLID {
    get {
      return graphQLMap["id"] as! GraphQLID
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }
}

public struct CreateOvertimeInviteInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID? = nil, postingId: GraphQLID, officerId: String, bucket: String, sequence: Int, reason: String, status: OvertimeInviteStatus, respondedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
    graphQLMap = ["id": id, "postingId": postingId, "officerId": officerId, "bucket": bucket, "sequence": sequence, "reason": reason, "status": status, "respondedAt": respondedAt, "createdAt": createdAt, "updatedAt": updatedAt]
  }

  public var id: GraphQLID? {
    get {
      return graphQLMap["id"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var postingId: GraphQLID {
    get {
      return graphQLMap["postingId"] as! GraphQLID
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "postingId")
    }
  }

  public var officerId: String {
    get {
      return graphQLMap["officerId"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "officerId")
    }
  }

  public var bucket: String {
    get {
      return graphQLMap["bucket"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "bucket")
    }
  }

  public var sequence: Int {
    get {
      return graphQLMap["sequence"] as! Int
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "sequence")
    }
  }

  public var reason: String {
    get {
      return graphQLMap["reason"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "reason")
    }
  }

  public var status: OvertimeInviteStatus {
    get {
      return graphQLMap["status"] as! OvertimeInviteStatus
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "status")
    }
  }

  public var respondedAt: String? {
    get {
      return graphQLMap["respondedAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "respondedAt")
    }
  }

  public var createdAt: String? {
    get {
      return graphQLMap["createdAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: String? {
    get {
      return graphQLMap["updatedAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }
}

public struct ModelOvertimeInviteConditionInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(postingId: ModelIDInput? = nil, officerId: ModelStringInput? = nil, bucket: ModelStringInput? = nil, sequence: ModelIntInput? = nil, reason: ModelStringInput? = nil, status: ModelOvertimeInviteStatusInput? = nil, respondedAt: ModelStringInput? = nil, createdAt: ModelStringInput? = nil, updatedAt: ModelStringInput? = nil, and: [ModelOvertimeInviteConditionInput?]? = nil, or: [ModelOvertimeInviteConditionInput?]? = nil, not: ModelOvertimeInviteConditionInput? = nil) {
    graphQLMap = ["postingId": postingId, "officerId": officerId, "bucket": bucket, "sequence": sequence, "reason": reason, "status": status, "respondedAt": respondedAt, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "not": not]
  }

  public var postingId: ModelIDInput? {
    get {
      return graphQLMap["postingId"] as! ModelIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "postingId")
    }
  }

  public var officerId: ModelStringInput? {
    get {
      return graphQLMap["officerId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "officerId")
    }
  }

  public var bucket: ModelStringInput? {
    get {
      return graphQLMap["bucket"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "bucket")
    }
  }

  public var sequence: ModelIntInput? {
    get {
      return graphQLMap["sequence"] as! ModelIntInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "sequence")
    }
  }

  public var reason: ModelStringInput? {
    get {
      return graphQLMap["reason"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "reason")
    }
  }

  public var status: ModelOvertimeInviteStatusInput? {
    get {
      return graphQLMap["status"] as! ModelOvertimeInviteStatusInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "status")
    }
  }

  public var respondedAt: ModelStringInput? {
    get {
      return graphQLMap["respondedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "respondedAt")
    }
  }

  public var createdAt: ModelStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelOvertimeInviteConditionInput?]? {
    get {
      return graphQLMap["and"] as! [ModelOvertimeInviteConditionInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelOvertimeInviteConditionInput?]? {
    get {
      return graphQLMap["or"] as! [ModelOvertimeInviteConditionInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var not: ModelOvertimeInviteConditionInput? {
    get {
      return graphQLMap["not"] as! ModelOvertimeInviteConditionInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "not")
    }
  }
}

public struct ModelIDInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(ne: GraphQLID? = nil, eq: GraphQLID? = nil, le: GraphQLID? = nil, lt: GraphQLID? = nil, ge: GraphQLID? = nil, gt: GraphQLID? = nil, contains: GraphQLID? = nil, notContains: GraphQLID? = nil, between: [GraphQLID?]? = nil, beginsWith: GraphQLID? = nil, attributeExists: Bool? = nil, attributeType: ModelAttributeTypes? = nil, size: ModelSizeInput? = nil) {
    graphQLMap = ["ne": ne, "eq": eq, "le": le, "lt": lt, "ge": ge, "gt": gt, "contains": contains, "notContains": notContains, "between": between, "beginsWith": beginsWith, "attributeExists": attributeExists, "attributeType": attributeType, "size": size]
  }

  public var ne: GraphQLID? {
    get {
      return graphQLMap["ne"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ne")
    }
  }

  public var eq: GraphQLID? {
    get {
      return graphQLMap["eq"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "eq")
    }
  }

  public var le: GraphQLID? {
    get {
      return graphQLMap["le"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "le")
    }
  }

  public var lt: GraphQLID? {
    get {
      return graphQLMap["lt"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "lt")
    }
  }

  public var ge: GraphQLID? {
    get {
      return graphQLMap["ge"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ge")
    }
  }

  public var gt: GraphQLID? {
    get {
      return graphQLMap["gt"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "gt")
    }
  }

  public var contains: GraphQLID? {
    get {
      return graphQLMap["contains"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "contains")
    }
  }

  public var notContains: GraphQLID? {
    get {
      return graphQLMap["notContains"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "notContains")
    }
  }

  public var between: [GraphQLID?]? {
    get {
      return graphQLMap["between"] as! [GraphQLID?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "between")
    }
  }

  public var beginsWith: GraphQLID? {
    get {
      return graphQLMap["beginsWith"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "beginsWith")
    }
  }

  public var attributeExists: Bool? {
    get {
      return graphQLMap["attributeExists"] as! Bool?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "attributeExists")
    }
  }

  public var attributeType: ModelAttributeTypes? {
    get {
      return graphQLMap["attributeType"] as! ModelAttributeTypes?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "attributeType")
    }
  }

  public var size: ModelSizeInput? {
    get {
      return graphQLMap["size"] as! ModelSizeInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "size")
    }
  }
}

public struct ModelOvertimeInviteStatusInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(eq: OvertimeInviteStatus? = nil, ne: OvertimeInviteStatus? = nil) {
    graphQLMap = ["eq": eq, "ne": ne]
  }

  public var eq: OvertimeInviteStatus? {
    get {
      return graphQLMap["eq"] as! OvertimeInviteStatus?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "eq")
    }
  }

  public var ne: OvertimeInviteStatus? {
    get {
      return graphQLMap["ne"] as! OvertimeInviteStatus?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ne")
    }
  }
}

public struct UpdateOvertimeInviteInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID, postingId: GraphQLID? = nil, officerId: String? = nil, bucket: String? = nil, sequence: Int? = nil, reason: String? = nil, status: OvertimeInviteStatus? = nil, respondedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
    graphQLMap = ["id": id, "postingId": postingId, "officerId": officerId, "bucket": bucket, "sequence": sequence, "reason": reason, "status": status, "respondedAt": respondedAt, "createdAt": createdAt, "updatedAt": updatedAt]
  }

  public var id: GraphQLID {
    get {
      return graphQLMap["id"] as! GraphQLID
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var postingId: GraphQLID? {
    get {
      return graphQLMap["postingId"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "postingId")
    }
  }

  public var officerId: String? {
    get {
      return graphQLMap["officerId"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "officerId")
    }
  }

  public var bucket: String? {
    get {
      return graphQLMap["bucket"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "bucket")
    }
  }

  public var sequence: Int? {
    get {
      return graphQLMap["sequence"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "sequence")
    }
  }

  public var reason: String? {
    get {
      return graphQLMap["reason"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "reason")
    }
  }

  public var status: OvertimeInviteStatus? {
    get {
      return graphQLMap["status"] as! OvertimeInviteStatus?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "status")
    }
  }

  public var respondedAt: String? {
    get {
      return graphQLMap["respondedAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "respondedAt")
    }
  }

  public var createdAt: String? {
    get {
      return graphQLMap["createdAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: String? {
    get {
      return graphQLMap["updatedAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }
}

public struct DeleteOvertimeInviteInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID) {
    graphQLMap = ["id": id]
  }

  public var id: GraphQLID {
    get {
      return graphQLMap["id"] as! GraphQLID
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }
}

public struct CreateOvertimeAuditEventInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID? = nil, postingId: GraphQLID, type: String, details: String? = nil, createdBy: String? = nil, createdAt: String? = nil) {
    graphQLMap = ["id": id, "postingId": postingId, "type": type, "details": details, "createdBy": createdBy, "createdAt": createdAt]
  }

  public var id: GraphQLID? {
    get {
      return graphQLMap["id"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var postingId: GraphQLID {
    get {
      return graphQLMap["postingId"] as! GraphQLID
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "postingId")
    }
  }

  public var type: String {
    get {
      return graphQLMap["type"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "type")
    }
  }

  public var details: String? {
    get {
      return graphQLMap["details"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "details")
    }
  }

  public var createdBy: String? {
    get {
      return graphQLMap["createdBy"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdBy")
    }
  }

  public var createdAt: String? {
    get {
      return graphQLMap["createdAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }
}

public struct ModelOvertimeAuditEventConditionInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(postingId: ModelIDInput? = nil, type: ModelStringInput? = nil, details: ModelStringInput? = nil, createdBy: ModelStringInput? = nil, createdAt: ModelStringInput? = nil, and: [ModelOvertimeAuditEventConditionInput?]? = nil, or: [ModelOvertimeAuditEventConditionInput?]? = nil, not: ModelOvertimeAuditEventConditionInput? = nil, updatedAt: ModelStringInput? = nil) {
    graphQLMap = ["postingId": postingId, "type": type, "details": details, "createdBy": createdBy, "createdAt": createdAt, "and": and, "or": or, "not": not, "updatedAt": updatedAt]
  }

  public var postingId: ModelIDInput? {
    get {
      return graphQLMap["postingId"] as! ModelIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "postingId")
    }
  }

  public var type: ModelStringInput? {
    get {
      return graphQLMap["type"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "type")
    }
  }

  public var details: ModelStringInput? {
    get {
      return graphQLMap["details"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "details")
    }
  }

  public var createdBy: ModelStringInput? {
    get {
      return graphQLMap["createdBy"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdBy")
    }
  }

  public var createdAt: ModelStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var and: [ModelOvertimeAuditEventConditionInput?]? {
    get {
      return graphQLMap["and"] as! [ModelOvertimeAuditEventConditionInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelOvertimeAuditEventConditionInput?]? {
    get {
      return graphQLMap["or"] as! [ModelOvertimeAuditEventConditionInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var not: ModelOvertimeAuditEventConditionInput? {
    get {
      return graphQLMap["not"] as! ModelOvertimeAuditEventConditionInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "not")
    }
  }

  public var updatedAt: ModelStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }
}

public struct UpdateOvertimeAuditEventInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID, postingId: GraphQLID? = nil, type: String? = nil, details: String? = nil, createdBy: String? = nil, createdAt: String? = nil) {
    graphQLMap = ["id": id, "postingId": postingId, "type": type, "details": details, "createdBy": createdBy, "createdAt": createdAt]
  }

  public var id: GraphQLID {
    get {
      return graphQLMap["id"] as! GraphQLID
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var postingId: GraphQLID? {
    get {
      return graphQLMap["postingId"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "postingId")
    }
  }

  public var type: String? {
    get {
      return graphQLMap["type"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "type")
    }
  }

  public var details: String? {
    get {
      return graphQLMap["details"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "details")
    }
  }

  public var createdBy: String? {
    get {
      return graphQLMap["createdBy"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdBy")
    }
  }

  public var createdAt: String? {
    get {
      return graphQLMap["createdAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }
}

public struct DeleteOvertimeAuditEventInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID) {
    graphQLMap = ["id": id]
  }

  public var id: GraphQLID {
    get {
      return graphQLMap["id"] as! GraphQLID
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }
}

public struct CreateNotificationEndpointInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID? = nil, orgId: String, userId: String, deviceToken: String, platform: NotificationPlatform, deviceName: String? = nil, enabled: Bool, platformEndpointArn: String? = nil, lastUsedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "userId": userId, "deviceToken": deviceToken, "platform": platform, "deviceName": deviceName, "enabled": enabled, "platformEndpointArn": platformEndpointArn, "lastUsedAt": lastUsedAt, "createdAt": createdAt, "updatedAt": updatedAt]
  }

  public var id: GraphQLID? {
    get {
      return graphQLMap["id"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: String {
    get {
      return graphQLMap["orgId"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var userId: String {
    get {
      return graphQLMap["userId"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "userId")
    }
  }

  public var deviceToken: String {
    get {
      return graphQLMap["deviceToken"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "deviceToken")
    }
  }

  public var platform: NotificationPlatform {
    get {
      return graphQLMap["platform"] as! NotificationPlatform
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "platform")
    }
  }

  public var deviceName: String? {
    get {
      return graphQLMap["deviceName"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "deviceName")
    }
  }

  public var enabled: Bool {
    get {
      return graphQLMap["enabled"] as! Bool
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "enabled")
    }
  }

  public var platformEndpointArn: String? {
    get {
      return graphQLMap["platformEndpointArn"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "platformEndpointArn")
    }
  }

  public var lastUsedAt: String? {
    get {
      return graphQLMap["lastUsedAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "lastUsedAt")
    }
  }

  public var createdAt: String? {
    get {
      return graphQLMap["createdAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: String? {
    get {
      return graphQLMap["updatedAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }
}

public enum NotificationPlatform: RawRepresentable, Equatable, JSONDecodable, JSONEncodable {
  public typealias RawValue = String
  case ios
  case android
  /// Auto generated constant for unknown enum values
  case unknown(RawValue)

  public init?(rawValue: RawValue) {
    switch rawValue {
      case "IOS": self = .ios
      case "ANDROID": self = .android
      default: self = .unknown(rawValue)
    }
  }

  public var rawValue: RawValue {
    switch self {
      case .ios: return "IOS"
      case .android: return "ANDROID"
      case .unknown(let value): return value
    }
  }

  public static func == (lhs: NotificationPlatform, rhs: NotificationPlatform) -> Bool {
    switch (lhs, rhs) {
      case (.ios, .ios): return true
      case (.android, .android): return true
      case (.unknown(let lhsValue), .unknown(let rhsValue)): return lhsValue == rhsValue
      default: return false
    }
  }
}

public struct ModelNotificationEndpointConditionInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(orgId: ModelStringInput? = nil, userId: ModelStringInput? = nil, deviceToken: ModelStringInput? = nil, platform: ModelNotificationPlatformInput? = nil, deviceName: ModelStringInput? = nil, enabled: ModelBooleanInput? = nil, platformEndpointArn: ModelStringInput? = nil, lastUsedAt: ModelStringInput? = nil, createdAt: ModelStringInput? = nil, updatedAt: ModelStringInput? = nil, and: [ModelNotificationEndpointConditionInput?]? = nil, or: [ModelNotificationEndpointConditionInput?]? = nil, not: ModelNotificationEndpointConditionInput? = nil) {
    graphQLMap = ["orgId": orgId, "userId": userId, "deviceToken": deviceToken, "platform": platform, "deviceName": deviceName, "enabled": enabled, "platformEndpointArn": platformEndpointArn, "lastUsedAt": lastUsedAt, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "not": not]
  }

  public var orgId: ModelStringInput? {
    get {
      return graphQLMap["orgId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var userId: ModelStringInput? {
    get {
      return graphQLMap["userId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "userId")
    }
  }

  public var deviceToken: ModelStringInput? {
    get {
      return graphQLMap["deviceToken"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "deviceToken")
    }
  }

  public var platform: ModelNotificationPlatformInput? {
    get {
      return graphQLMap["platform"] as! ModelNotificationPlatformInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "platform")
    }
  }

  public var deviceName: ModelStringInput? {
    get {
      return graphQLMap["deviceName"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "deviceName")
    }
  }

  public var enabled: ModelBooleanInput? {
    get {
      return graphQLMap["enabled"] as! ModelBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "enabled")
    }
  }

  public var platformEndpointArn: ModelStringInput? {
    get {
      return graphQLMap["platformEndpointArn"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "platformEndpointArn")
    }
  }

  public var lastUsedAt: ModelStringInput? {
    get {
      return graphQLMap["lastUsedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "lastUsedAt")
    }
  }

  public var createdAt: ModelStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelNotificationEndpointConditionInput?]? {
    get {
      return graphQLMap["and"] as! [ModelNotificationEndpointConditionInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelNotificationEndpointConditionInput?]? {
    get {
      return graphQLMap["or"] as! [ModelNotificationEndpointConditionInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var not: ModelNotificationEndpointConditionInput? {
    get {
      return graphQLMap["not"] as! ModelNotificationEndpointConditionInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "not")
    }
  }
}

public struct ModelNotificationPlatformInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(eq: NotificationPlatform? = nil, ne: NotificationPlatform? = nil) {
    graphQLMap = ["eq": eq, "ne": ne]
  }

  public var eq: NotificationPlatform? {
    get {
      return graphQLMap["eq"] as! NotificationPlatform?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "eq")
    }
  }

  public var ne: NotificationPlatform? {
    get {
      return graphQLMap["ne"] as! NotificationPlatform?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ne")
    }
  }
}

public struct UpdateNotificationEndpointInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID, orgId: String? = nil, userId: String? = nil, deviceToken: String? = nil, platform: NotificationPlatform? = nil, deviceName: String? = nil, enabled: Bool? = nil, platformEndpointArn: String? = nil, lastUsedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "userId": userId, "deviceToken": deviceToken, "platform": platform, "deviceName": deviceName, "enabled": enabled, "platformEndpointArn": platformEndpointArn, "lastUsedAt": lastUsedAt, "createdAt": createdAt, "updatedAt": updatedAt]
  }

  public var id: GraphQLID {
    get {
      return graphQLMap["id"] as! GraphQLID
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: String? {
    get {
      return graphQLMap["orgId"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var userId: String? {
    get {
      return graphQLMap["userId"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "userId")
    }
  }

  public var deviceToken: String? {
    get {
      return graphQLMap["deviceToken"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "deviceToken")
    }
  }

  public var platform: NotificationPlatform? {
    get {
      return graphQLMap["platform"] as! NotificationPlatform?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "platform")
    }
  }

  public var deviceName: String? {
    get {
      return graphQLMap["deviceName"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "deviceName")
    }
  }

  public var enabled: Bool? {
    get {
      return graphQLMap["enabled"] as! Bool?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "enabled")
    }
  }

  public var platformEndpointArn: String? {
    get {
      return graphQLMap["platformEndpointArn"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "platformEndpointArn")
    }
  }

  public var lastUsedAt: String? {
    get {
      return graphQLMap["lastUsedAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "lastUsedAt")
    }
  }

  public var createdAt: String? {
    get {
      return graphQLMap["createdAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: String? {
    get {
      return graphQLMap["updatedAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }
}

public struct DeleteNotificationEndpointInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID) {
    graphQLMap = ["id": id]
  }

  public var id: GraphQLID {
    get {
      return graphQLMap["id"] as! GraphQLID
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }
}

public struct CreateNotificationMessageInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID? = nil, orgId: String, title: String, body: String, category: NotificationCategory, recipients: [String], metadata: String? = nil, createdBy: String, createdAt: String? = nil, updatedAt: String? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "title": title, "body": body, "category": category, "recipients": recipients, "metadata": metadata, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt]
  }

  public var id: GraphQLID? {
    get {
      return graphQLMap["id"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: String {
    get {
      return graphQLMap["orgId"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var title: String {
    get {
      return graphQLMap["title"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "title")
    }
  }

  public var body: String {
    get {
      return graphQLMap["body"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "body")
    }
  }

  public var category: NotificationCategory {
    get {
      return graphQLMap["category"] as! NotificationCategory
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "category")
    }
  }

  public var recipients: [String] {
    get {
      return graphQLMap["recipients"] as! [String]
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "recipients")
    }
  }

  public var metadata: String? {
    get {
      return graphQLMap["metadata"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "metadata")
    }
  }

  public var createdBy: String {
    get {
      return graphQLMap["createdBy"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdBy")
    }
  }

  public var createdAt: String? {
    get {
      return graphQLMap["createdAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: String? {
    get {
      return graphQLMap["updatedAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }
}

public struct ModelNotificationMessageConditionInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(orgId: ModelStringInput? = nil, title: ModelStringInput? = nil, body: ModelStringInput? = nil, category: ModelNotificationCategoryInput? = nil, recipients: ModelStringInput? = nil, metadata: ModelStringInput? = nil, createdBy: ModelStringInput? = nil, createdAt: ModelStringInput? = nil, updatedAt: ModelStringInput? = nil, and: [ModelNotificationMessageConditionInput?]? = nil, or: [ModelNotificationMessageConditionInput?]? = nil, not: ModelNotificationMessageConditionInput? = nil) {
    graphQLMap = ["orgId": orgId, "title": title, "body": body, "category": category, "recipients": recipients, "metadata": metadata, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "not": not]
  }

  public var orgId: ModelStringInput? {
    get {
      return graphQLMap["orgId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var title: ModelStringInput? {
    get {
      return graphQLMap["title"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "title")
    }
  }

  public var body: ModelStringInput? {
    get {
      return graphQLMap["body"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "body")
    }
  }

  public var category: ModelNotificationCategoryInput? {
    get {
      return graphQLMap["category"] as! ModelNotificationCategoryInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "category")
    }
  }

  public var recipients: ModelStringInput? {
    get {
      return graphQLMap["recipients"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "recipients")
    }
  }

  public var metadata: ModelStringInput? {
    get {
      return graphQLMap["metadata"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "metadata")
    }
  }

  public var createdBy: ModelStringInput? {
    get {
      return graphQLMap["createdBy"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdBy")
    }
  }

  public var createdAt: ModelStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelNotificationMessageConditionInput?]? {
    get {
      return graphQLMap["and"] as! [ModelNotificationMessageConditionInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelNotificationMessageConditionInput?]? {
    get {
      return graphQLMap["or"] as! [ModelNotificationMessageConditionInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var not: ModelNotificationMessageConditionInput? {
    get {
      return graphQLMap["not"] as! ModelNotificationMessageConditionInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "not")
    }
  }
}

public struct ModelNotificationCategoryInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(eq: NotificationCategory? = nil, ne: NotificationCategory? = nil) {
    graphQLMap = ["eq": eq, "ne": ne]
  }

  public var eq: NotificationCategory? {
    get {
      return graphQLMap["eq"] as! NotificationCategory?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "eq")
    }
  }

  public var ne: NotificationCategory? {
    get {
      return graphQLMap["ne"] as! NotificationCategory?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ne")
    }
  }
}

public struct UpdateNotificationMessageInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID, orgId: String? = nil, title: String? = nil, body: String? = nil, category: NotificationCategory? = nil, recipients: [String]? = nil, metadata: String? = nil, createdBy: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "title": title, "body": body, "category": category, "recipients": recipients, "metadata": metadata, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt]
  }

  public var id: GraphQLID {
    get {
      return graphQLMap["id"] as! GraphQLID
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: String? {
    get {
      return graphQLMap["orgId"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var title: String? {
    get {
      return graphQLMap["title"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "title")
    }
  }

  public var body: String? {
    get {
      return graphQLMap["body"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "body")
    }
  }

  public var category: NotificationCategory? {
    get {
      return graphQLMap["category"] as! NotificationCategory?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "category")
    }
  }

  public var recipients: [String]? {
    get {
      return graphQLMap["recipients"] as! [String]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "recipients")
    }
  }

  public var metadata: String? {
    get {
      return graphQLMap["metadata"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "metadata")
    }
  }

  public var createdBy: String? {
    get {
      return graphQLMap["createdBy"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdBy")
    }
  }

  public var createdAt: String? {
    get {
      return graphQLMap["createdAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: String? {
    get {
      return graphQLMap["updatedAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }
}

public struct DeleteNotificationMessageInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID) {
    graphQLMap = ["id": id]
  }

  public var id: GraphQLID {
    get {
      return graphQLMap["id"] as! GraphQLID
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }
}

public struct CreateNotificationPreferenceInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID? = nil, userId: String, generalBulletin: Bool, taskAlert: Bool, overtime: Bool, squadMessages: Bool, other: Bool, contactPhone: String? = nil, contactEmail: String? = nil, backupEmail: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
    graphQLMap = ["id": id, "userId": userId, "generalBulletin": generalBulletin, "taskAlert": taskAlert, "overtime": overtime, "squadMessages": squadMessages, "other": other, "contactPhone": contactPhone, "contactEmail": contactEmail, "backupEmail": backupEmail, "createdAt": createdAt, "updatedAt": updatedAt]
  }

  public var id: GraphQLID? {
    get {
      return graphQLMap["id"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var userId: String {
    get {
      return graphQLMap["userId"] as! String
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "userId")
    }
  }

  public var generalBulletin: Bool {
    get {
      return graphQLMap["generalBulletin"] as! Bool
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "generalBulletin")
    }
  }

  public var taskAlert: Bool {
    get {
      return graphQLMap["taskAlert"] as! Bool
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "taskAlert")
    }
  }

  public var overtime: Bool {
    get {
      return graphQLMap["overtime"] as! Bool
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "overtime")
    }
  }

  public var squadMessages: Bool {
    get {
      return graphQLMap["squadMessages"] as! Bool
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "squadMessages")
    }
  }

  public var other: Bool {
    get {
      return graphQLMap["other"] as! Bool
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "other")
    }
  }

  public var contactPhone: String? {
    get {
      return graphQLMap["contactPhone"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "contactPhone")
    }
  }

  public var contactEmail: String? {
    get {
      return graphQLMap["contactEmail"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "contactEmail")
    }
  }

  public var backupEmail: String? {
    get {
      return graphQLMap["backupEmail"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "backupEmail")
    }
  }

  public var createdAt: String? {
    get {
      return graphQLMap["createdAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: String? {
    get {
      return graphQLMap["updatedAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }
}

public struct ModelNotificationPreferenceConditionInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(userId: ModelStringInput? = nil, generalBulletin: ModelBooleanInput? = nil, taskAlert: ModelBooleanInput? = nil, overtime: ModelBooleanInput? = nil, squadMessages: ModelBooleanInput? = nil, other: ModelBooleanInput? = nil, contactPhone: ModelStringInput? = nil, contactEmail: ModelStringInput? = nil, backupEmail: ModelStringInput? = nil, createdAt: ModelStringInput? = nil, updatedAt: ModelStringInput? = nil, and: [ModelNotificationPreferenceConditionInput?]? = nil, or: [ModelNotificationPreferenceConditionInput?]? = nil, not: ModelNotificationPreferenceConditionInput? = nil) {
    graphQLMap = ["userId": userId, "generalBulletin": generalBulletin, "taskAlert": taskAlert, "overtime": overtime, "squadMessages": squadMessages, "other": other, "contactPhone": contactPhone, "contactEmail": contactEmail, "backupEmail": backupEmail, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "not": not]
  }

  public var userId: ModelStringInput? {
    get {
      return graphQLMap["userId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "userId")
    }
  }

  public var generalBulletin: ModelBooleanInput? {
    get {
      return graphQLMap["generalBulletin"] as! ModelBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "generalBulletin")
    }
  }

  public var taskAlert: ModelBooleanInput? {
    get {
      return graphQLMap["taskAlert"] as! ModelBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "taskAlert")
    }
  }

  public var overtime: ModelBooleanInput? {
    get {
      return graphQLMap["overtime"] as! ModelBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "overtime")
    }
  }

  public var squadMessages: ModelBooleanInput? {
    get {
      return graphQLMap["squadMessages"] as! ModelBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "squadMessages")
    }
  }

  public var other: ModelBooleanInput? {
    get {
      return graphQLMap["other"] as! ModelBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "other")
    }
  }

  public var contactPhone: ModelStringInput? {
    get {
      return graphQLMap["contactPhone"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "contactPhone")
    }
  }

  public var contactEmail: ModelStringInput? {
    get {
      return graphQLMap["contactEmail"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "contactEmail")
    }
  }

  public var backupEmail: ModelStringInput? {
    get {
      return graphQLMap["backupEmail"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "backupEmail")
    }
  }

  public var createdAt: ModelStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelNotificationPreferenceConditionInput?]? {
    get {
      return graphQLMap["and"] as! [ModelNotificationPreferenceConditionInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelNotificationPreferenceConditionInput?]? {
    get {
      return graphQLMap["or"] as! [ModelNotificationPreferenceConditionInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var not: ModelNotificationPreferenceConditionInput? {
    get {
      return graphQLMap["not"] as! ModelNotificationPreferenceConditionInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "not")
    }
  }
}

public struct UpdateNotificationPreferenceInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID, userId: String? = nil, generalBulletin: Bool? = nil, taskAlert: Bool? = nil, overtime: Bool? = nil, squadMessages: Bool? = nil, other: Bool? = nil, contactPhone: String? = nil, contactEmail: String? = nil, backupEmail: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
    graphQLMap = ["id": id, "userId": userId, "generalBulletin": generalBulletin, "taskAlert": taskAlert, "overtime": overtime, "squadMessages": squadMessages, "other": other, "contactPhone": contactPhone, "contactEmail": contactEmail, "backupEmail": backupEmail, "createdAt": createdAt, "updatedAt": updatedAt]
  }

  public var id: GraphQLID {
    get {
      return graphQLMap["id"] as! GraphQLID
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var userId: String? {
    get {
      return graphQLMap["userId"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "userId")
    }
  }

  public var generalBulletin: Bool? {
    get {
      return graphQLMap["generalBulletin"] as! Bool?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "generalBulletin")
    }
  }

  public var taskAlert: Bool? {
    get {
      return graphQLMap["taskAlert"] as! Bool?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "taskAlert")
    }
  }

  public var overtime: Bool? {
    get {
      return graphQLMap["overtime"] as! Bool?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "overtime")
    }
  }

  public var squadMessages: Bool? {
    get {
      return graphQLMap["squadMessages"] as! Bool?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "squadMessages")
    }
  }

  public var other: Bool? {
    get {
      return graphQLMap["other"] as! Bool?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "other")
    }
  }

  public var contactPhone: String? {
    get {
      return graphQLMap["contactPhone"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "contactPhone")
    }
  }

  public var contactEmail: String? {
    get {
      return graphQLMap["contactEmail"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "contactEmail")
    }
  }

  public var backupEmail: String? {
    get {
      return graphQLMap["backupEmail"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "backupEmail")
    }
  }

  public var createdAt: String? {
    get {
      return graphQLMap["createdAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: String? {
    get {
      return graphQLMap["updatedAt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }
}

public struct DeleteNotificationPreferenceInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: GraphQLID) {
    graphQLMap = ["id": id]
  }

  public var id: GraphQLID {
    get {
      return graphQLMap["id"] as! GraphQLID
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }
}

public struct ModelRosterEntryFilterInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: ModelIDInput? = nil, orgId: ModelStringInput? = nil, badgeNumber: ModelStringInput? = nil, shift: ModelStringInput? = nil, startsAt: ModelStringInput? = nil, endsAt: ModelStringInput? = nil, notes: ModelStringInput? = nil, createdAt: ModelStringInput? = nil, updatedAt: ModelStringInput? = nil, and: [ModelRosterEntryFilterInput?]? = nil, or: [ModelRosterEntryFilterInput?]? = nil, not: ModelRosterEntryFilterInput? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "badgeNumber": badgeNumber, "shift": shift, "startsAt": startsAt, "endsAt": endsAt, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "not": not]
  }

  public var id: ModelIDInput? {
    get {
      return graphQLMap["id"] as! ModelIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: ModelStringInput? {
    get {
      return graphQLMap["orgId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var badgeNumber: ModelStringInput? {
    get {
      return graphQLMap["badgeNumber"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "badgeNumber")
    }
  }

  public var shift: ModelStringInput? {
    get {
      return graphQLMap["shift"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "shift")
    }
  }

  public var startsAt: ModelStringInput? {
    get {
      return graphQLMap["startsAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "startsAt")
    }
  }

  public var endsAt: ModelStringInput? {
    get {
      return graphQLMap["endsAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "endsAt")
    }
  }

  public var notes: ModelStringInput? {
    get {
      return graphQLMap["notes"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "notes")
    }
  }

  public var createdAt: ModelStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelRosterEntryFilterInput?]? {
    get {
      return graphQLMap["and"] as! [ModelRosterEntryFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelRosterEntryFilterInput?]? {
    get {
      return graphQLMap["or"] as! [ModelRosterEntryFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var not: ModelRosterEntryFilterInput? {
    get {
      return graphQLMap["not"] as! ModelRosterEntryFilterInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "not")
    }
  }
}

public struct ModelStringKeyConditionInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(eq: String? = nil, le: String? = nil, lt: String? = nil, ge: String? = nil, gt: String? = nil, between: [String?]? = nil, beginsWith: String? = nil) {
    graphQLMap = ["eq": eq, "le": le, "lt": lt, "ge": ge, "gt": gt, "between": between, "beginsWith": beginsWith]
  }

  public var eq: String? {
    get {
      return graphQLMap["eq"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "eq")
    }
  }

  public var le: String? {
    get {
      return graphQLMap["le"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "le")
    }
  }

  public var lt: String? {
    get {
      return graphQLMap["lt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "lt")
    }
  }

  public var ge: String? {
    get {
      return graphQLMap["ge"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ge")
    }
  }

  public var gt: String? {
    get {
      return graphQLMap["gt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "gt")
    }
  }

  public var between: [String?]? {
    get {
      return graphQLMap["between"] as! [String?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "between")
    }
  }

  public var beginsWith: String? {
    get {
      return graphQLMap["beginsWith"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "beginsWith")
    }
  }
}

public enum ModelSortDirection: RawRepresentable, Equatable, JSONDecodable, JSONEncodable {
  public typealias RawValue = String
  case asc
  case desc
  /// Auto generated constant for unknown enum values
  case unknown(RawValue)

  public init?(rawValue: RawValue) {
    switch rawValue {
      case "ASC": self = .asc
      case "DESC": self = .desc
      default: self = .unknown(rawValue)
    }
  }

  public var rawValue: RawValue {
    switch self {
      case .asc: return "ASC"
      case .desc: return "DESC"
      case .unknown(let value): return value
    }
  }

  public static func == (lhs: ModelSortDirection, rhs: ModelSortDirection) -> Bool {
    switch (lhs, rhs) {
      case (.asc, .asc): return true
      case (.desc, .desc): return true
      case (.unknown(let lhsValue), .unknown(let rhsValue)): return lhsValue == rhsValue
      default: return false
    }
  }
}

public struct ModelVehicleFilterInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: ModelIDInput? = nil, orgId: ModelStringInput? = nil, callsign: ModelStringInput? = nil, make: ModelStringInput? = nil, model: ModelStringInput? = nil, plate: ModelStringInput? = nil, inService: ModelBooleanInput? = nil, createdAt: ModelStringInput? = nil, updatedAt: ModelStringInput? = nil, and: [ModelVehicleFilterInput?]? = nil, or: [ModelVehicleFilterInput?]? = nil, not: ModelVehicleFilterInput? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "callsign": callsign, "make": make, "model": model, "plate": plate, "inService": inService, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "not": not]
  }

  public var id: ModelIDInput? {
    get {
      return graphQLMap["id"] as! ModelIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: ModelStringInput? {
    get {
      return graphQLMap["orgId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var callsign: ModelStringInput? {
    get {
      return graphQLMap["callsign"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "callsign")
    }
  }

  public var make: ModelStringInput? {
    get {
      return graphQLMap["make"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "make")
    }
  }

  public var model: ModelStringInput? {
    get {
      return graphQLMap["model"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "model")
    }
  }

  public var plate: ModelStringInput? {
    get {
      return graphQLMap["plate"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "plate")
    }
  }

  public var inService: ModelBooleanInput? {
    get {
      return graphQLMap["inService"] as! ModelBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "inService")
    }
  }

  public var createdAt: ModelStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelVehicleFilterInput?]? {
    get {
      return graphQLMap["and"] as! [ModelVehicleFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelVehicleFilterInput?]? {
    get {
      return graphQLMap["or"] as! [ModelVehicleFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var not: ModelVehicleFilterInput? {
    get {
      return graphQLMap["not"] as! ModelVehicleFilterInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "not")
    }
  }
}

public struct ModelCalendarEventFilterInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: ModelIDInput? = nil, orgId: ModelStringInput? = nil, ownerId: ModelStringInput? = nil, title: ModelStringInput? = nil, category: ModelStringInput? = nil, color: ModelStringInput? = nil, notes: ModelStringInput? = nil, startsAt: ModelStringInput? = nil, endsAt: ModelStringInput? = nil, reminderMinutesBefore: ModelIntInput? = nil, createdAt: ModelStringInput? = nil, updatedAt: ModelStringInput? = nil, and: [ModelCalendarEventFilterInput?]? = nil, or: [ModelCalendarEventFilterInput?]? = nil, not: ModelCalendarEventFilterInput? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "ownerId": ownerId, "title": title, "category": category, "color": color, "notes": notes, "startsAt": startsAt, "endsAt": endsAt, "reminderMinutesBefore": reminderMinutesBefore, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "not": not]
  }

  public var id: ModelIDInput? {
    get {
      return graphQLMap["id"] as! ModelIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: ModelStringInput? {
    get {
      return graphQLMap["orgId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var ownerId: ModelStringInput? {
    get {
      return graphQLMap["ownerId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ownerId")
    }
  }

  public var title: ModelStringInput? {
    get {
      return graphQLMap["title"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "title")
    }
  }

  public var category: ModelStringInput? {
    get {
      return graphQLMap["category"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "category")
    }
  }

  public var color: ModelStringInput? {
    get {
      return graphQLMap["color"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "color")
    }
  }

  public var notes: ModelStringInput? {
    get {
      return graphQLMap["notes"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "notes")
    }
  }

  public var startsAt: ModelStringInput? {
    get {
      return graphQLMap["startsAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "startsAt")
    }
  }

  public var endsAt: ModelStringInput? {
    get {
      return graphQLMap["endsAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "endsAt")
    }
  }

  public var reminderMinutesBefore: ModelIntInput? {
    get {
      return graphQLMap["reminderMinutesBefore"] as! ModelIntInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "reminderMinutesBefore")
    }
  }

  public var createdAt: ModelStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelCalendarEventFilterInput?]? {
    get {
      return graphQLMap["and"] as! [ModelCalendarEventFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelCalendarEventFilterInput?]? {
    get {
      return graphQLMap["or"] as! [ModelCalendarEventFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var not: ModelCalendarEventFilterInput? {
    get {
      return graphQLMap["not"] as! ModelCalendarEventFilterInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "not")
    }
  }
}

public struct ModelOfficerAssignmentFilterInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: ModelIDInput? = nil, orgId: ModelStringInput? = nil, badgeNumber: ModelStringInput? = nil, title: ModelStringInput? = nil, detail: ModelStringInput? = nil, location: ModelStringInput? = nil, notes: ModelStringInput? = nil, createdAt: ModelStringInput? = nil, updatedAt: ModelStringInput? = nil, and: [ModelOfficerAssignmentFilterInput?]? = nil, or: [ModelOfficerAssignmentFilterInput?]? = nil, not: ModelOfficerAssignmentFilterInput? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "badgeNumber": badgeNumber, "title": title, "detail": detail, "location": location, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "not": not]
  }

  public var id: ModelIDInput? {
    get {
      return graphQLMap["id"] as! ModelIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: ModelStringInput? {
    get {
      return graphQLMap["orgId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var badgeNumber: ModelStringInput? {
    get {
      return graphQLMap["badgeNumber"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "badgeNumber")
    }
  }

  public var title: ModelStringInput? {
    get {
      return graphQLMap["title"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "title")
    }
  }

  public var detail: ModelStringInput? {
    get {
      return graphQLMap["detail"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "detail")
    }
  }

  public var location: ModelStringInput? {
    get {
      return graphQLMap["location"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "location")
    }
  }

  public var notes: ModelStringInput? {
    get {
      return graphQLMap["notes"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "notes")
    }
  }

  public var createdAt: ModelStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelOfficerAssignmentFilterInput?]? {
    get {
      return graphQLMap["and"] as! [ModelOfficerAssignmentFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelOfficerAssignmentFilterInput?]? {
    get {
      return graphQLMap["or"] as! [ModelOfficerAssignmentFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var not: ModelOfficerAssignmentFilterInput? {
    get {
      return graphQLMap["not"] as! ModelOfficerAssignmentFilterInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "not")
    }
  }
}

public struct ModelOvertimePostingFilterInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: ModelIDInput? = nil, orgId: ModelStringInput? = nil, title: ModelStringInput? = nil, location: ModelStringInput? = nil, scenario: ModelOvertimeScenarioInput? = nil, startsAt: ModelStringInput? = nil, endsAt: ModelStringInput? = nil, slots: ModelIntInput? = nil, policySnapshot: ModelStringInput? = nil, selectionPolicy: ModelOvertimeSelectionPolicyInput? = nil, needsEscalation: ModelBooleanInput? = nil, state: ModelOvertimePostingStateInput? = nil, createdBy: ModelStringInput? = nil, createdAt: ModelStringInput? = nil, updatedAt: ModelStringInput? = nil, and: [ModelOvertimePostingFilterInput?]? = nil, or: [ModelOvertimePostingFilterInput?]? = nil, not: ModelOvertimePostingFilterInput? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "title": title, "location": location, "scenario": scenario, "startsAt": startsAt, "endsAt": endsAt, "slots": slots, "policySnapshot": policySnapshot, "selectionPolicy": selectionPolicy, "needsEscalation": needsEscalation, "state": state, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "not": not]
  }

  public var id: ModelIDInput? {
    get {
      return graphQLMap["id"] as! ModelIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: ModelStringInput? {
    get {
      return graphQLMap["orgId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var title: ModelStringInput? {
    get {
      return graphQLMap["title"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "title")
    }
  }

  public var location: ModelStringInput? {
    get {
      return graphQLMap["location"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "location")
    }
  }

  public var scenario: ModelOvertimeScenarioInput? {
    get {
      return graphQLMap["scenario"] as! ModelOvertimeScenarioInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "scenario")
    }
  }

  public var startsAt: ModelStringInput? {
    get {
      return graphQLMap["startsAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "startsAt")
    }
  }

  public var endsAt: ModelStringInput? {
    get {
      return graphQLMap["endsAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "endsAt")
    }
  }

  public var slots: ModelIntInput? {
    get {
      return graphQLMap["slots"] as! ModelIntInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "slots")
    }
  }

  public var policySnapshot: ModelStringInput? {
    get {
      return graphQLMap["policySnapshot"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "policySnapshot")
    }
  }

  public var selectionPolicy: ModelOvertimeSelectionPolicyInput? {
    get {
      return graphQLMap["selectionPolicy"] as! ModelOvertimeSelectionPolicyInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "selectionPolicy")
    }
  }

  public var needsEscalation: ModelBooleanInput? {
    get {
      return graphQLMap["needsEscalation"] as! ModelBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "needsEscalation")
    }
  }

  public var state: ModelOvertimePostingStateInput? {
    get {
      return graphQLMap["state"] as! ModelOvertimePostingStateInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "state")
    }
  }

  public var createdBy: ModelStringInput? {
    get {
      return graphQLMap["createdBy"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdBy")
    }
  }

  public var createdAt: ModelStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelOvertimePostingFilterInput?]? {
    get {
      return graphQLMap["and"] as! [ModelOvertimePostingFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelOvertimePostingFilterInput?]? {
    get {
      return graphQLMap["or"] as! [ModelOvertimePostingFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var not: ModelOvertimePostingFilterInput? {
    get {
      return graphQLMap["not"] as! ModelOvertimePostingFilterInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "not")
    }
  }
}

public struct ModelOvertimeInviteFilterInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: ModelIDInput? = nil, postingId: ModelIDInput? = nil, officerId: ModelStringInput? = nil, bucket: ModelStringInput? = nil, sequence: ModelIntInput? = nil, reason: ModelStringInput? = nil, status: ModelOvertimeInviteStatusInput? = nil, respondedAt: ModelStringInput? = nil, createdAt: ModelStringInput? = nil, updatedAt: ModelStringInput? = nil, and: [ModelOvertimeInviteFilterInput?]? = nil, or: [ModelOvertimeInviteFilterInput?]? = nil, not: ModelOvertimeInviteFilterInput? = nil) {
    graphQLMap = ["id": id, "postingId": postingId, "officerId": officerId, "bucket": bucket, "sequence": sequence, "reason": reason, "status": status, "respondedAt": respondedAt, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "not": not]
  }

  public var id: ModelIDInput? {
    get {
      return graphQLMap["id"] as! ModelIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var postingId: ModelIDInput? {
    get {
      return graphQLMap["postingId"] as! ModelIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "postingId")
    }
  }

  public var officerId: ModelStringInput? {
    get {
      return graphQLMap["officerId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "officerId")
    }
  }

  public var bucket: ModelStringInput? {
    get {
      return graphQLMap["bucket"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "bucket")
    }
  }

  public var sequence: ModelIntInput? {
    get {
      return graphQLMap["sequence"] as! ModelIntInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "sequence")
    }
  }

  public var reason: ModelStringInput? {
    get {
      return graphQLMap["reason"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "reason")
    }
  }

  public var status: ModelOvertimeInviteStatusInput? {
    get {
      return graphQLMap["status"] as! ModelOvertimeInviteStatusInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "status")
    }
  }

  public var respondedAt: ModelStringInput? {
    get {
      return graphQLMap["respondedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "respondedAt")
    }
  }

  public var createdAt: ModelStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelOvertimeInviteFilterInput?]? {
    get {
      return graphQLMap["and"] as! [ModelOvertimeInviteFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelOvertimeInviteFilterInput?]? {
    get {
      return graphQLMap["or"] as! [ModelOvertimeInviteFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var not: ModelOvertimeInviteFilterInput? {
    get {
      return graphQLMap["not"] as! ModelOvertimeInviteFilterInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "not")
    }
  }
}

public struct ModelIntKeyConditionInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(eq: Int? = nil, le: Int? = nil, lt: Int? = nil, ge: Int? = nil, gt: Int? = nil, between: [Int?]? = nil) {
    graphQLMap = ["eq": eq, "le": le, "lt": lt, "ge": ge, "gt": gt, "between": between]
  }

  public var eq: Int? {
    get {
      return graphQLMap["eq"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "eq")
    }
  }

  public var le: Int? {
    get {
      return graphQLMap["le"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "le")
    }
  }

  public var lt: Int? {
    get {
      return graphQLMap["lt"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "lt")
    }
  }

  public var ge: Int? {
    get {
      return graphQLMap["ge"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ge")
    }
  }

  public var gt: Int? {
    get {
      return graphQLMap["gt"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "gt")
    }
  }

  public var between: [Int?]? {
    get {
      return graphQLMap["between"] as! [Int?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "between")
    }
  }
}

public struct ModelOvertimeAuditEventFilterInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: ModelIDInput? = nil, postingId: ModelIDInput? = nil, type: ModelStringInput? = nil, details: ModelStringInput? = nil, createdBy: ModelStringInput? = nil, createdAt: ModelStringInput? = nil, updatedAt: ModelStringInput? = nil, and: [ModelOvertimeAuditEventFilterInput?]? = nil, or: [ModelOvertimeAuditEventFilterInput?]? = nil, not: ModelOvertimeAuditEventFilterInput? = nil) {
    graphQLMap = ["id": id, "postingId": postingId, "type": type, "details": details, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "not": not]
  }

  public var id: ModelIDInput? {
    get {
      return graphQLMap["id"] as! ModelIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var postingId: ModelIDInput? {
    get {
      return graphQLMap["postingId"] as! ModelIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "postingId")
    }
  }

  public var type: ModelStringInput? {
    get {
      return graphQLMap["type"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "type")
    }
  }

  public var details: ModelStringInput? {
    get {
      return graphQLMap["details"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "details")
    }
  }

  public var createdBy: ModelStringInput? {
    get {
      return graphQLMap["createdBy"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdBy")
    }
  }

  public var createdAt: ModelStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelOvertimeAuditEventFilterInput?]? {
    get {
      return graphQLMap["and"] as! [ModelOvertimeAuditEventFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelOvertimeAuditEventFilterInput?]? {
    get {
      return graphQLMap["or"] as! [ModelOvertimeAuditEventFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var not: ModelOvertimeAuditEventFilterInput? {
    get {
      return graphQLMap["not"] as! ModelOvertimeAuditEventFilterInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "not")
    }
  }
}

public struct ModelNotificationEndpointFilterInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: ModelIDInput? = nil, orgId: ModelStringInput? = nil, userId: ModelStringInput? = nil, deviceToken: ModelStringInput? = nil, platform: ModelNotificationPlatformInput? = nil, deviceName: ModelStringInput? = nil, enabled: ModelBooleanInput? = nil, platformEndpointArn: ModelStringInput? = nil, lastUsedAt: ModelStringInput? = nil, createdAt: ModelStringInput? = nil, updatedAt: ModelStringInput? = nil, and: [ModelNotificationEndpointFilterInput?]? = nil, or: [ModelNotificationEndpointFilterInput?]? = nil, not: ModelNotificationEndpointFilterInput? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "userId": userId, "deviceToken": deviceToken, "platform": platform, "deviceName": deviceName, "enabled": enabled, "platformEndpointArn": platformEndpointArn, "lastUsedAt": lastUsedAt, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "not": not]
  }

  public var id: ModelIDInput? {
    get {
      return graphQLMap["id"] as! ModelIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: ModelStringInput? {
    get {
      return graphQLMap["orgId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var userId: ModelStringInput? {
    get {
      return graphQLMap["userId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "userId")
    }
  }

  public var deviceToken: ModelStringInput? {
    get {
      return graphQLMap["deviceToken"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "deviceToken")
    }
  }

  public var platform: ModelNotificationPlatformInput? {
    get {
      return graphQLMap["platform"] as! ModelNotificationPlatformInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "platform")
    }
  }

  public var deviceName: ModelStringInput? {
    get {
      return graphQLMap["deviceName"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "deviceName")
    }
  }

  public var enabled: ModelBooleanInput? {
    get {
      return graphQLMap["enabled"] as! ModelBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "enabled")
    }
  }

  public var platformEndpointArn: ModelStringInput? {
    get {
      return graphQLMap["platformEndpointArn"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "platformEndpointArn")
    }
  }

  public var lastUsedAt: ModelStringInput? {
    get {
      return graphQLMap["lastUsedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "lastUsedAt")
    }
  }

  public var createdAt: ModelStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelNotificationEndpointFilterInput?]? {
    get {
      return graphQLMap["and"] as! [ModelNotificationEndpointFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelNotificationEndpointFilterInput?]? {
    get {
      return graphQLMap["or"] as! [ModelNotificationEndpointFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var not: ModelNotificationEndpointFilterInput? {
    get {
      return graphQLMap["not"] as! ModelNotificationEndpointFilterInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "not")
    }
  }
}

public struct ModelNotificationMessageFilterInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: ModelIDInput? = nil, orgId: ModelStringInput? = nil, title: ModelStringInput? = nil, body: ModelStringInput? = nil, category: ModelNotificationCategoryInput? = nil, recipients: ModelStringInput? = nil, metadata: ModelStringInput? = nil, createdBy: ModelStringInput? = nil, createdAt: ModelStringInput? = nil, updatedAt: ModelStringInput? = nil, and: [ModelNotificationMessageFilterInput?]? = nil, or: [ModelNotificationMessageFilterInput?]? = nil, not: ModelNotificationMessageFilterInput? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "title": title, "body": body, "category": category, "recipients": recipients, "metadata": metadata, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "not": not]
  }

  public var id: ModelIDInput? {
    get {
      return graphQLMap["id"] as! ModelIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: ModelStringInput? {
    get {
      return graphQLMap["orgId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var title: ModelStringInput? {
    get {
      return graphQLMap["title"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "title")
    }
  }

  public var body: ModelStringInput? {
    get {
      return graphQLMap["body"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "body")
    }
  }

  public var category: ModelNotificationCategoryInput? {
    get {
      return graphQLMap["category"] as! ModelNotificationCategoryInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "category")
    }
  }

  public var recipients: ModelStringInput? {
    get {
      return graphQLMap["recipients"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "recipients")
    }
  }

  public var metadata: ModelStringInput? {
    get {
      return graphQLMap["metadata"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "metadata")
    }
  }

  public var createdBy: ModelStringInput? {
    get {
      return graphQLMap["createdBy"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdBy")
    }
  }

  public var createdAt: ModelStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelNotificationMessageFilterInput?]? {
    get {
      return graphQLMap["and"] as! [ModelNotificationMessageFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelNotificationMessageFilterInput?]? {
    get {
      return graphQLMap["or"] as! [ModelNotificationMessageFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var not: ModelNotificationMessageFilterInput? {
    get {
      return graphQLMap["not"] as! ModelNotificationMessageFilterInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "not")
    }
  }
}

public struct ModelNotificationPreferenceFilterInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: ModelIDInput? = nil, userId: ModelStringInput? = nil, generalBulletin: ModelBooleanInput? = nil, taskAlert: ModelBooleanInput? = nil, overtime: ModelBooleanInput? = nil, squadMessages: ModelBooleanInput? = nil, other: ModelBooleanInput? = nil, contactPhone: ModelStringInput? = nil, contactEmail: ModelStringInput? = nil, backupEmail: ModelStringInput? = nil, createdAt: ModelStringInput? = nil, updatedAt: ModelStringInput? = nil, and: [ModelNotificationPreferenceFilterInput?]? = nil, or: [ModelNotificationPreferenceFilterInput?]? = nil, not: ModelNotificationPreferenceFilterInput? = nil) {
    graphQLMap = ["id": id, "userId": userId, "generalBulletin": generalBulletin, "taskAlert": taskAlert, "overtime": overtime, "squadMessages": squadMessages, "other": other, "contactPhone": contactPhone, "contactEmail": contactEmail, "backupEmail": backupEmail, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "not": not]
  }

  public var id: ModelIDInput? {
    get {
      return graphQLMap["id"] as! ModelIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var userId: ModelStringInput? {
    get {
      return graphQLMap["userId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "userId")
    }
  }

  public var generalBulletin: ModelBooleanInput? {
    get {
      return graphQLMap["generalBulletin"] as! ModelBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "generalBulletin")
    }
  }

  public var taskAlert: ModelBooleanInput? {
    get {
      return graphQLMap["taskAlert"] as! ModelBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "taskAlert")
    }
  }

  public var overtime: ModelBooleanInput? {
    get {
      return graphQLMap["overtime"] as! ModelBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "overtime")
    }
  }

  public var squadMessages: ModelBooleanInput? {
    get {
      return graphQLMap["squadMessages"] as! ModelBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "squadMessages")
    }
  }

  public var other: ModelBooleanInput? {
    get {
      return graphQLMap["other"] as! ModelBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "other")
    }
  }

  public var contactPhone: ModelStringInput? {
    get {
      return graphQLMap["contactPhone"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "contactPhone")
    }
  }

  public var contactEmail: ModelStringInput? {
    get {
      return graphQLMap["contactEmail"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "contactEmail")
    }
  }

  public var backupEmail: ModelStringInput? {
    get {
      return graphQLMap["backupEmail"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "backupEmail")
    }
  }

  public var createdAt: ModelStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelNotificationPreferenceFilterInput?]? {
    get {
      return graphQLMap["and"] as! [ModelNotificationPreferenceFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelNotificationPreferenceFilterInput?]? {
    get {
      return graphQLMap["or"] as! [ModelNotificationPreferenceFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var not: ModelNotificationPreferenceFilterInput? {
    get {
      return graphQLMap["not"] as! ModelNotificationPreferenceFilterInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "not")
    }
  }
}

public struct ModelSubscriptionRosterEntryFilterInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: ModelSubscriptionIDInput? = nil, orgId: ModelSubscriptionStringInput? = nil, shift: ModelSubscriptionStringInput? = nil, startsAt: ModelSubscriptionStringInput? = nil, endsAt: ModelSubscriptionStringInput? = nil, notes: ModelSubscriptionStringInput? = nil, createdAt: ModelSubscriptionStringInput? = nil, updatedAt: ModelSubscriptionStringInput? = nil, and: [ModelSubscriptionRosterEntryFilterInput?]? = nil, or: [ModelSubscriptionRosterEntryFilterInput?]? = nil, badgeNumber: ModelStringInput? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "shift": shift, "startsAt": startsAt, "endsAt": endsAt, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "badgeNumber": badgeNumber]
  }

  public var id: ModelSubscriptionIDInput? {
    get {
      return graphQLMap["id"] as! ModelSubscriptionIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["orgId"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var shift: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["shift"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "shift")
    }
  }

  public var startsAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["startsAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "startsAt")
    }
  }

  public var endsAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["endsAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "endsAt")
    }
  }

  public var notes: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["notes"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "notes")
    }
  }

  public var createdAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelSubscriptionRosterEntryFilterInput?]? {
    get {
      return graphQLMap["and"] as! [ModelSubscriptionRosterEntryFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelSubscriptionRosterEntryFilterInput?]? {
    get {
      return graphQLMap["or"] as! [ModelSubscriptionRosterEntryFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var badgeNumber: ModelStringInput? {
    get {
      return graphQLMap["badgeNumber"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "badgeNumber")
    }
  }
}

public struct ModelSubscriptionIDInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(ne: GraphQLID? = nil, eq: GraphQLID? = nil, le: GraphQLID? = nil, lt: GraphQLID? = nil, ge: GraphQLID? = nil, gt: GraphQLID? = nil, contains: GraphQLID? = nil, notContains: GraphQLID? = nil, between: [GraphQLID?]? = nil, beginsWith: GraphQLID? = nil, `in`: [GraphQLID?]? = nil, notIn: [GraphQLID?]? = nil) {
    graphQLMap = ["ne": ne, "eq": eq, "le": le, "lt": lt, "ge": ge, "gt": gt, "contains": contains, "notContains": notContains, "between": between, "beginsWith": beginsWith, "in": `in`, "notIn": notIn]
  }

  public var ne: GraphQLID? {
    get {
      return graphQLMap["ne"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ne")
    }
  }

  public var eq: GraphQLID? {
    get {
      return graphQLMap["eq"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "eq")
    }
  }

  public var le: GraphQLID? {
    get {
      return graphQLMap["le"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "le")
    }
  }

  public var lt: GraphQLID? {
    get {
      return graphQLMap["lt"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "lt")
    }
  }

  public var ge: GraphQLID? {
    get {
      return graphQLMap["ge"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ge")
    }
  }

  public var gt: GraphQLID? {
    get {
      return graphQLMap["gt"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "gt")
    }
  }

  public var contains: GraphQLID? {
    get {
      return graphQLMap["contains"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "contains")
    }
  }

  public var notContains: GraphQLID? {
    get {
      return graphQLMap["notContains"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "notContains")
    }
  }

  public var between: [GraphQLID?]? {
    get {
      return graphQLMap["between"] as! [GraphQLID?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "between")
    }
  }

  public var beginsWith: GraphQLID? {
    get {
      return graphQLMap["beginsWith"] as! GraphQLID?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "beginsWith")
    }
  }

  public var `in`: [GraphQLID?]? {
    get {
      return graphQLMap["in"] as! [GraphQLID?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "in")
    }
  }

  public var notIn: [GraphQLID?]? {
    get {
      return graphQLMap["notIn"] as! [GraphQLID?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "notIn")
    }
  }
}

public struct ModelSubscriptionStringInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(ne: String? = nil, eq: String? = nil, le: String? = nil, lt: String? = nil, ge: String? = nil, gt: String? = nil, contains: String? = nil, notContains: String? = nil, between: [String?]? = nil, beginsWith: String? = nil, `in`: [String?]? = nil, notIn: [String?]? = nil) {
    graphQLMap = ["ne": ne, "eq": eq, "le": le, "lt": lt, "ge": ge, "gt": gt, "contains": contains, "notContains": notContains, "between": between, "beginsWith": beginsWith, "in": `in`, "notIn": notIn]
  }

  public var ne: String? {
    get {
      return graphQLMap["ne"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ne")
    }
  }

  public var eq: String? {
    get {
      return graphQLMap["eq"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "eq")
    }
  }

  public var le: String? {
    get {
      return graphQLMap["le"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "le")
    }
  }

  public var lt: String? {
    get {
      return graphQLMap["lt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "lt")
    }
  }

  public var ge: String? {
    get {
      return graphQLMap["ge"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ge")
    }
  }

  public var gt: String? {
    get {
      return graphQLMap["gt"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "gt")
    }
  }

  public var contains: String? {
    get {
      return graphQLMap["contains"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "contains")
    }
  }

  public var notContains: String? {
    get {
      return graphQLMap["notContains"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "notContains")
    }
  }

  public var between: [String?]? {
    get {
      return graphQLMap["between"] as! [String?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "between")
    }
  }

  public var beginsWith: String? {
    get {
      return graphQLMap["beginsWith"] as! String?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "beginsWith")
    }
  }

  public var `in`: [String?]? {
    get {
      return graphQLMap["in"] as! [String?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "in")
    }
  }

  public var notIn: [String?]? {
    get {
      return graphQLMap["notIn"] as! [String?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "notIn")
    }
  }
}

public struct ModelSubscriptionVehicleFilterInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: ModelSubscriptionIDInput? = nil, orgId: ModelSubscriptionStringInput? = nil, callsign: ModelSubscriptionStringInput? = nil, make: ModelSubscriptionStringInput? = nil, model: ModelSubscriptionStringInput? = nil, plate: ModelSubscriptionStringInput? = nil, inService: ModelSubscriptionBooleanInput? = nil, createdAt: ModelSubscriptionStringInput? = nil, updatedAt: ModelSubscriptionStringInput? = nil, and: [ModelSubscriptionVehicleFilterInput?]? = nil, or: [ModelSubscriptionVehicleFilterInput?]? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "callsign": callsign, "make": make, "model": model, "plate": plate, "inService": inService, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or]
  }

  public var id: ModelSubscriptionIDInput? {
    get {
      return graphQLMap["id"] as! ModelSubscriptionIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["orgId"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var callsign: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["callsign"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "callsign")
    }
  }

  public var make: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["make"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "make")
    }
  }

  public var model: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["model"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "model")
    }
  }

  public var plate: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["plate"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "plate")
    }
  }

  public var inService: ModelSubscriptionBooleanInput? {
    get {
      return graphQLMap["inService"] as! ModelSubscriptionBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "inService")
    }
  }

  public var createdAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelSubscriptionVehicleFilterInput?]? {
    get {
      return graphQLMap["and"] as! [ModelSubscriptionVehicleFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelSubscriptionVehicleFilterInput?]? {
    get {
      return graphQLMap["or"] as! [ModelSubscriptionVehicleFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }
}

public struct ModelSubscriptionBooleanInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(ne: Bool? = nil, eq: Bool? = nil) {
    graphQLMap = ["ne": ne, "eq": eq]
  }

  public var ne: Bool? {
    get {
      return graphQLMap["ne"] as! Bool?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ne")
    }
  }

  public var eq: Bool? {
    get {
      return graphQLMap["eq"] as! Bool?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "eq")
    }
  }
}

public struct ModelSubscriptionCalendarEventFilterInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: ModelSubscriptionIDInput? = nil, orgId: ModelSubscriptionStringInput? = nil, title: ModelSubscriptionStringInput? = nil, category: ModelSubscriptionStringInput? = nil, color: ModelSubscriptionStringInput? = nil, notes: ModelSubscriptionStringInput? = nil, startsAt: ModelSubscriptionStringInput? = nil, endsAt: ModelSubscriptionStringInput? = nil, reminderMinutesBefore: ModelSubscriptionIntInput? = nil, createdAt: ModelSubscriptionStringInput? = nil, updatedAt: ModelSubscriptionStringInput? = nil, and: [ModelSubscriptionCalendarEventFilterInput?]? = nil, or: [ModelSubscriptionCalendarEventFilterInput?]? = nil, ownerId: ModelStringInput? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "title": title, "category": category, "color": color, "notes": notes, "startsAt": startsAt, "endsAt": endsAt, "reminderMinutesBefore": reminderMinutesBefore, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "ownerId": ownerId]
  }

  public var id: ModelSubscriptionIDInput? {
    get {
      return graphQLMap["id"] as! ModelSubscriptionIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["orgId"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var title: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["title"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "title")
    }
  }

  public var category: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["category"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "category")
    }
  }

  public var color: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["color"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "color")
    }
  }

  public var notes: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["notes"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "notes")
    }
  }

  public var startsAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["startsAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "startsAt")
    }
  }

  public var endsAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["endsAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "endsAt")
    }
  }

  public var reminderMinutesBefore: ModelSubscriptionIntInput? {
    get {
      return graphQLMap["reminderMinutesBefore"] as! ModelSubscriptionIntInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "reminderMinutesBefore")
    }
  }

  public var createdAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelSubscriptionCalendarEventFilterInput?]? {
    get {
      return graphQLMap["and"] as! [ModelSubscriptionCalendarEventFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelSubscriptionCalendarEventFilterInput?]? {
    get {
      return graphQLMap["or"] as! [ModelSubscriptionCalendarEventFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var ownerId: ModelStringInput? {
    get {
      return graphQLMap["ownerId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ownerId")
    }
  }
}

public struct ModelSubscriptionIntInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(ne: Int? = nil, eq: Int? = nil, le: Int? = nil, lt: Int? = nil, ge: Int? = nil, gt: Int? = nil, between: [Int?]? = nil, `in`: [Int?]? = nil, notIn: [Int?]? = nil) {
    graphQLMap = ["ne": ne, "eq": eq, "le": le, "lt": lt, "ge": ge, "gt": gt, "between": between, "in": `in`, "notIn": notIn]
  }

  public var ne: Int? {
    get {
      return graphQLMap["ne"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ne")
    }
  }

  public var eq: Int? {
    get {
      return graphQLMap["eq"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "eq")
    }
  }

  public var le: Int? {
    get {
      return graphQLMap["le"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "le")
    }
  }

  public var lt: Int? {
    get {
      return graphQLMap["lt"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "lt")
    }
  }

  public var ge: Int? {
    get {
      return graphQLMap["ge"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "ge")
    }
  }

  public var gt: Int? {
    get {
      return graphQLMap["gt"] as! Int?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "gt")
    }
  }

  public var between: [Int?]? {
    get {
      return graphQLMap["between"] as! [Int?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "between")
    }
  }

  public var `in`: [Int?]? {
    get {
      return graphQLMap["in"] as! [Int?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "in")
    }
  }

  public var notIn: [Int?]? {
    get {
      return graphQLMap["notIn"] as! [Int?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "notIn")
    }
  }
}

public struct ModelSubscriptionOfficerAssignmentFilterInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: ModelSubscriptionIDInput? = nil, orgId: ModelSubscriptionStringInput? = nil, title: ModelSubscriptionStringInput? = nil, detail: ModelSubscriptionStringInput? = nil, location: ModelSubscriptionStringInput? = nil, notes: ModelSubscriptionStringInput? = nil, createdAt: ModelSubscriptionStringInput? = nil, updatedAt: ModelSubscriptionStringInput? = nil, and: [ModelSubscriptionOfficerAssignmentFilterInput?]? = nil, or: [ModelSubscriptionOfficerAssignmentFilterInput?]? = nil, badgeNumber: ModelStringInput? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "title": title, "detail": detail, "location": location, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "badgeNumber": badgeNumber]
  }

  public var id: ModelSubscriptionIDInput? {
    get {
      return graphQLMap["id"] as! ModelSubscriptionIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["orgId"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var title: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["title"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "title")
    }
  }

  public var detail: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["detail"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "detail")
    }
  }

  public var location: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["location"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "location")
    }
  }

  public var notes: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["notes"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "notes")
    }
  }

  public var createdAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelSubscriptionOfficerAssignmentFilterInput?]? {
    get {
      return graphQLMap["and"] as! [ModelSubscriptionOfficerAssignmentFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelSubscriptionOfficerAssignmentFilterInput?]? {
    get {
      return graphQLMap["or"] as! [ModelSubscriptionOfficerAssignmentFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var badgeNumber: ModelStringInput? {
    get {
      return graphQLMap["badgeNumber"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "badgeNumber")
    }
  }
}

public struct ModelSubscriptionOvertimePostingFilterInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: ModelSubscriptionIDInput? = nil, orgId: ModelSubscriptionStringInput? = nil, title: ModelSubscriptionStringInput? = nil, location: ModelSubscriptionStringInput? = nil, scenario: ModelSubscriptionStringInput? = nil, startsAt: ModelSubscriptionStringInput? = nil, endsAt: ModelSubscriptionStringInput? = nil, slots: ModelSubscriptionIntInput? = nil, policySnapshot: ModelSubscriptionStringInput? = nil, selectionPolicy: ModelSubscriptionStringInput? = nil, needsEscalation: ModelSubscriptionBooleanInput? = nil, state: ModelSubscriptionStringInput? = nil, createdAt: ModelSubscriptionStringInput? = nil, updatedAt: ModelSubscriptionStringInput? = nil, and: [ModelSubscriptionOvertimePostingFilterInput?]? = nil, or: [ModelSubscriptionOvertimePostingFilterInput?]? = nil, createdBy: ModelStringInput? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "title": title, "location": location, "scenario": scenario, "startsAt": startsAt, "endsAt": endsAt, "slots": slots, "policySnapshot": policySnapshot, "selectionPolicy": selectionPolicy, "needsEscalation": needsEscalation, "state": state, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "createdBy": createdBy]
  }

  public var id: ModelSubscriptionIDInput? {
    get {
      return graphQLMap["id"] as! ModelSubscriptionIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["orgId"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var title: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["title"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "title")
    }
  }

  public var location: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["location"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "location")
    }
  }

  public var scenario: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["scenario"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "scenario")
    }
  }

  public var startsAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["startsAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "startsAt")
    }
  }

  public var endsAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["endsAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "endsAt")
    }
  }

  public var slots: ModelSubscriptionIntInput? {
    get {
      return graphQLMap["slots"] as! ModelSubscriptionIntInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "slots")
    }
  }

  public var policySnapshot: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["policySnapshot"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "policySnapshot")
    }
  }

  public var selectionPolicy: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["selectionPolicy"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "selectionPolicy")
    }
  }

  public var needsEscalation: ModelSubscriptionBooleanInput? {
    get {
      return graphQLMap["needsEscalation"] as! ModelSubscriptionBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "needsEscalation")
    }
  }

  public var state: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["state"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "state")
    }
  }

  public var createdAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelSubscriptionOvertimePostingFilterInput?]? {
    get {
      return graphQLMap["and"] as! [ModelSubscriptionOvertimePostingFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelSubscriptionOvertimePostingFilterInput?]? {
    get {
      return graphQLMap["or"] as! [ModelSubscriptionOvertimePostingFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var createdBy: ModelStringInput? {
    get {
      return graphQLMap["createdBy"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdBy")
    }
  }
}

public struct ModelSubscriptionOvertimeInviteFilterInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: ModelSubscriptionIDInput? = nil, postingId: ModelSubscriptionIDInput? = nil, bucket: ModelSubscriptionStringInput? = nil, sequence: ModelSubscriptionIntInput? = nil, reason: ModelSubscriptionStringInput? = nil, status: ModelSubscriptionStringInput? = nil, respondedAt: ModelSubscriptionStringInput? = nil, createdAt: ModelSubscriptionStringInput? = nil, updatedAt: ModelSubscriptionStringInput? = nil, and: [ModelSubscriptionOvertimeInviteFilterInput?]? = nil, or: [ModelSubscriptionOvertimeInviteFilterInput?]? = nil, officerId: ModelStringInput? = nil) {
    graphQLMap = ["id": id, "postingId": postingId, "bucket": bucket, "sequence": sequence, "reason": reason, "status": status, "respondedAt": respondedAt, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "officerId": officerId]
  }

  public var id: ModelSubscriptionIDInput? {
    get {
      return graphQLMap["id"] as! ModelSubscriptionIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var postingId: ModelSubscriptionIDInput? {
    get {
      return graphQLMap["postingId"] as! ModelSubscriptionIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "postingId")
    }
  }

  public var bucket: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["bucket"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "bucket")
    }
  }

  public var sequence: ModelSubscriptionIntInput? {
    get {
      return graphQLMap["sequence"] as! ModelSubscriptionIntInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "sequence")
    }
  }

  public var reason: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["reason"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "reason")
    }
  }

  public var status: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["status"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "status")
    }
  }

  public var respondedAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["respondedAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "respondedAt")
    }
  }

  public var createdAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelSubscriptionOvertimeInviteFilterInput?]? {
    get {
      return graphQLMap["and"] as! [ModelSubscriptionOvertimeInviteFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelSubscriptionOvertimeInviteFilterInput?]? {
    get {
      return graphQLMap["or"] as! [ModelSubscriptionOvertimeInviteFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var officerId: ModelStringInput? {
    get {
      return graphQLMap["officerId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "officerId")
    }
  }
}

public struct ModelSubscriptionOvertimeAuditEventFilterInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: ModelSubscriptionIDInput? = nil, postingId: ModelSubscriptionIDInput? = nil, type: ModelSubscriptionStringInput? = nil, details: ModelSubscriptionStringInput? = nil, createdBy: ModelSubscriptionStringInput? = nil, createdAt: ModelSubscriptionStringInput? = nil, updatedAt: ModelSubscriptionStringInput? = nil, and: [ModelSubscriptionOvertimeAuditEventFilterInput?]? = nil, or: [ModelSubscriptionOvertimeAuditEventFilterInput?]? = nil) {
    graphQLMap = ["id": id, "postingId": postingId, "type": type, "details": details, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or]
  }

  public var id: ModelSubscriptionIDInput? {
    get {
      return graphQLMap["id"] as! ModelSubscriptionIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var postingId: ModelSubscriptionIDInput? {
    get {
      return graphQLMap["postingId"] as! ModelSubscriptionIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "postingId")
    }
  }

  public var type: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["type"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "type")
    }
  }

  public var details: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["details"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "details")
    }
  }

  public var createdBy: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["createdBy"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdBy")
    }
  }

  public var createdAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelSubscriptionOvertimeAuditEventFilterInput?]? {
    get {
      return graphQLMap["and"] as! [ModelSubscriptionOvertimeAuditEventFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelSubscriptionOvertimeAuditEventFilterInput?]? {
    get {
      return graphQLMap["or"] as! [ModelSubscriptionOvertimeAuditEventFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }
}

public struct ModelSubscriptionNotificationEndpointFilterInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: ModelSubscriptionIDInput? = nil, orgId: ModelSubscriptionStringInput? = nil, deviceToken: ModelSubscriptionStringInput? = nil, platform: ModelSubscriptionStringInput? = nil, deviceName: ModelSubscriptionStringInput? = nil, enabled: ModelSubscriptionBooleanInput? = nil, platformEndpointArn: ModelSubscriptionStringInput? = nil, lastUsedAt: ModelSubscriptionStringInput? = nil, createdAt: ModelSubscriptionStringInput? = nil, updatedAt: ModelSubscriptionStringInput? = nil, and: [ModelSubscriptionNotificationEndpointFilterInput?]? = nil, or: [ModelSubscriptionNotificationEndpointFilterInput?]? = nil, userId: ModelStringInput? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "deviceToken": deviceToken, "platform": platform, "deviceName": deviceName, "enabled": enabled, "platformEndpointArn": platformEndpointArn, "lastUsedAt": lastUsedAt, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "userId": userId]
  }

  public var id: ModelSubscriptionIDInput? {
    get {
      return graphQLMap["id"] as! ModelSubscriptionIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["orgId"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var deviceToken: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["deviceToken"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "deviceToken")
    }
  }

  public var platform: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["platform"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "platform")
    }
  }

  public var deviceName: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["deviceName"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "deviceName")
    }
  }

  public var enabled: ModelSubscriptionBooleanInput? {
    get {
      return graphQLMap["enabled"] as! ModelSubscriptionBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "enabled")
    }
  }

  public var platformEndpointArn: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["platformEndpointArn"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "platformEndpointArn")
    }
  }

  public var lastUsedAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["lastUsedAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "lastUsedAt")
    }
  }

  public var createdAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelSubscriptionNotificationEndpointFilterInput?]? {
    get {
      return graphQLMap["and"] as! [ModelSubscriptionNotificationEndpointFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelSubscriptionNotificationEndpointFilterInput?]? {
    get {
      return graphQLMap["or"] as! [ModelSubscriptionNotificationEndpointFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var userId: ModelStringInput? {
    get {
      return graphQLMap["userId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "userId")
    }
  }
}

public struct ModelSubscriptionNotificationMessageFilterInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: ModelSubscriptionIDInput? = nil, orgId: ModelSubscriptionStringInput? = nil, title: ModelSubscriptionStringInput? = nil, body: ModelSubscriptionStringInput? = nil, category: ModelSubscriptionStringInput? = nil, recipients: ModelSubscriptionStringInput? = nil, metadata: ModelSubscriptionStringInput? = nil, createdBy: ModelSubscriptionStringInput? = nil, createdAt: ModelSubscriptionStringInput? = nil, updatedAt: ModelSubscriptionStringInput? = nil, and: [ModelSubscriptionNotificationMessageFilterInput?]? = nil, or: [ModelSubscriptionNotificationMessageFilterInput?]? = nil) {
    graphQLMap = ["id": id, "orgId": orgId, "title": title, "body": body, "category": category, "recipients": recipients, "metadata": metadata, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or]
  }

  public var id: ModelSubscriptionIDInput? {
    get {
      return graphQLMap["id"] as! ModelSubscriptionIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var orgId: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["orgId"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "orgId")
    }
  }

  public var title: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["title"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "title")
    }
  }

  public var body: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["body"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "body")
    }
  }

  public var category: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["category"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "category")
    }
  }

  public var recipients: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["recipients"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "recipients")
    }
  }

  public var metadata: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["metadata"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "metadata")
    }
  }

  public var createdBy: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["createdBy"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdBy")
    }
  }

  public var createdAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelSubscriptionNotificationMessageFilterInput?]? {
    get {
      return graphQLMap["and"] as! [ModelSubscriptionNotificationMessageFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelSubscriptionNotificationMessageFilterInput?]? {
    get {
      return graphQLMap["or"] as! [ModelSubscriptionNotificationMessageFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }
}

public struct ModelSubscriptionNotificationPreferenceFilterInput: GraphQLMapConvertible {
  public var graphQLMap: GraphQLMap

  public init(id: ModelSubscriptionIDInput? = nil, generalBulletin: ModelSubscriptionBooleanInput? = nil, taskAlert: ModelSubscriptionBooleanInput? = nil, overtime: ModelSubscriptionBooleanInput? = nil, squadMessages: ModelSubscriptionBooleanInput? = nil, other: ModelSubscriptionBooleanInput? = nil, contactPhone: ModelSubscriptionStringInput? = nil, contactEmail: ModelSubscriptionStringInput? = nil, backupEmail: ModelSubscriptionStringInput? = nil, createdAt: ModelSubscriptionStringInput? = nil, updatedAt: ModelSubscriptionStringInput? = nil, and: [ModelSubscriptionNotificationPreferenceFilterInput?]? = nil, or: [ModelSubscriptionNotificationPreferenceFilterInput?]? = nil, userId: ModelStringInput? = nil) {
    graphQLMap = ["id": id, "generalBulletin": generalBulletin, "taskAlert": taskAlert, "overtime": overtime, "squadMessages": squadMessages, "other": other, "contactPhone": contactPhone, "contactEmail": contactEmail, "backupEmail": backupEmail, "createdAt": createdAt, "updatedAt": updatedAt, "and": and, "or": or, "userId": userId]
  }

  public var id: ModelSubscriptionIDInput? {
    get {
      return graphQLMap["id"] as! ModelSubscriptionIDInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "id")
    }
  }

  public var generalBulletin: ModelSubscriptionBooleanInput? {
    get {
      return graphQLMap["generalBulletin"] as! ModelSubscriptionBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "generalBulletin")
    }
  }

  public var taskAlert: ModelSubscriptionBooleanInput? {
    get {
      return graphQLMap["taskAlert"] as! ModelSubscriptionBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "taskAlert")
    }
  }

  public var overtime: ModelSubscriptionBooleanInput? {
    get {
      return graphQLMap["overtime"] as! ModelSubscriptionBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "overtime")
    }
  }

  public var squadMessages: ModelSubscriptionBooleanInput? {
    get {
      return graphQLMap["squadMessages"] as! ModelSubscriptionBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "squadMessages")
    }
  }

  public var other: ModelSubscriptionBooleanInput? {
    get {
      return graphQLMap["other"] as! ModelSubscriptionBooleanInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "other")
    }
  }

  public var contactPhone: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["contactPhone"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "contactPhone")
    }
  }

  public var contactEmail: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["contactEmail"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "contactEmail")
    }
  }

  public var backupEmail: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["backupEmail"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "backupEmail")
    }
  }

  public var createdAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["createdAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "createdAt")
    }
  }

  public var updatedAt: ModelSubscriptionStringInput? {
    get {
      return graphQLMap["updatedAt"] as! ModelSubscriptionStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "updatedAt")
    }
  }

  public var and: [ModelSubscriptionNotificationPreferenceFilterInput?]? {
    get {
      return graphQLMap["and"] as! [ModelSubscriptionNotificationPreferenceFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "and")
    }
  }

  public var or: [ModelSubscriptionNotificationPreferenceFilterInput?]? {
    get {
      return graphQLMap["or"] as! [ModelSubscriptionNotificationPreferenceFilterInput?]?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "or")
    }
  }

  public var userId: ModelStringInput? {
    get {
      return graphQLMap["userId"] as! ModelStringInput?
    }
    set {
      graphQLMap.updateValue(newValue, forKey: "userId")
    }
  }
}

public final class NotifyOvertimeEventMutation: GraphQLMutation {
  public static let operationString =
    "mutation NotifyOvertimeEvent($input: OvertimeNotificationInput!) {\n  notifyOvertimeEvent(input: $input) {\n    __typename\n    success\n    delivered\n    recipientCount\n    message\n  }\n}"

  public var input: OvertimeNotificationInput

  public init(input: OvertimeNotificationInput) {
    self.input = input
  }

  public var variables: GraphQLMap? {
    return ["input": input]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("notifyOvertimeEvent", arguments: ["input": GraphQLVariable("input")], type: .object(NotifyOvertimeEvent.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(notifyOvertimeEvent: NotifyOvertimeEvent? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "notifyOvertimeEvent": notifyOvertimeEvent.flatMap { $0.snapshot }])
    }

    public var notifyOvertimeEvent: NotifyOvertimeEvent? {
      get {
        return (snapshot["notifyOvertimeEvent"] as? Snapshot).flatMap { NotifyOvertimeEvent(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "notifyOvertimeEvent")
      }
    }

    public struct NotifyOvertimeEvent: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationSendResult"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("success", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("delivered", type: .scalar(Int.self)),
        GraphQLField("recipientCount", type: .scalar(Int.self)),
        GraphQLField("message", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(success: Bool, delivered: Int? = nil, recipientCount: Int? = nil, message: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationSendResult", "success": success, "delivered": delivered, "recipientCount": recipientCount, "message": message])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var success: Bool {
        get {
          return snapshot["success"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "success")
        }
      }

      public var delivered: Int? {
        get {
          return snapshot["delivered"] as? Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "delivered")
        }
      }

      public var recipientCount: Int? {
        get {
          return snapshot["recipientCount"] as? Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "recipientCount")
        }
      }

      public var message: String? {
        get {
          return snapshot["message"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "message")
        }
      }
    }
  }
}

public final class SendNotificationMutation: GraphQLMutation {
  public static let operationString =
    "mutation SendNotification($input: OvertimeNotificationInput!) {\n  sendNotification(input: $input) {\n    __typename\n    success\n    delivered\n    recipientCount\n    message\n  }\n}"

  public var input: OvertimeNotificationInput

  public init(input: OvertimeNotificationInput) {
    self.input = input
  }

  public var variables: GraphQLMap? {
    return ["input": input]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("sendNotification", arguments: ["input": GraphQLVariable("input")], type: .object(SendNotification.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(sendNotification: SendNotification? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "sendNotification": sendNotification.flatMap { $0.snapshot }])
    }

    public var sendNotification: SendNotification? {
      get {
        return (snapshot["sendNotification"] as? Snapshot).flatMap { SendNotification(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "sendNotification")
      }
    }

    public struct SendNotification: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationSendResult"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("success", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("delivered", type: .scalar(Int.self)),
        GraphQLField("recipientCount", type: .scalar(Int.self)),
        GraphQLField("message", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(success: Bool, delivered: Int? = nil, recipientCount: Int? = nil, message: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationSendResult", "success": success, "delivered": delivered, "recipientCount": recipientCount, "message": message])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var success: Bool {
        get {
          return snapshot["success"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "success")
        }
      }

      public var delivered: Int? {
        get {
          return snapshot["delivered"] as? Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "delivered")
        }
      }

      public var recipientCount: Int? {
        get {
          return snapshot["recipientCount"] as? Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "recipientCount")
        }
      }

      public var message: String? {
        get {
          return snapshot["message"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "message")
        }
      }
    }
  }
}

public final class CreateRosterEntryMutation: GraphQLMutation {
  public static let operationString =
    "mutation CreateRosterEntry($input: CreateRosterEntryInput!, $condition: ModelRosterEntryConditionInput) {\n  createRosterEntry(input: $input, condition: $condition) {\n    __typename\n    id\n    orgId\n    badgeNumber\n    shift\n    startsAt\n    endsAt\n    notes\n    createdAt\n    updatedAt\n  }\n}"

  public var input: CreateRosterEntryInput
  public var condition: ModelRosterEntryConditionInput?

  public init(input: CreateRosterEntryInput, condition: ModelRosterEntryConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("createRosterEntry", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(CreateRosterEntry.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(createRosterEntry: CreateRosterEntry? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "createRosterEntry": createRosterEntry.flatMap { $0.snapshot }])
    }

    public var createRosterEntry: CreateRosterEntry? {
      get {
        return (snapshot["createRosterEntry"] as? Snapshot).flatMap { CreateRosterEntry(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "createRosterEntry")
      }
    }

    public struct CreateRosterEntry: GraphQLSelectionSet {
      public static let possibleTypes = ["RosterEntry"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("badgeNumber", type: .nonNull(.scalar(String.self))),
        GraphQLField("shift", type: .scalar(String.self)),
        GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("notes", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, badgeNumber: String, shift: String? = nil, startsAt: String, endsAt: String, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "RosterEntry", "id": id, "orgId": orgId, "badgeNumber": badgeNumber, "shift": shift, "startsAt": startsAt, "endsAt": endsAt, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var badgeNumber: String {
        get {
          return snapshot["badgeNumber"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "badgeNumber")
        }
      }

      public var shift: String? {
        get {
          return snapshot["shift"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "shift")
        }
      }

      public var startsAt: String {
        get {
          return snapshot["startsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "startsAt")
        }
      }

      public var endsAt: String {
        get {
          return snapshot["endsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "endsAt")
        }
      }

      public var notes: String? {
        get {
          return snapshot["notes"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "notes")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class UpdateRosterEntryMutation: GraphQLMutation {
  public static let operationString =
    "mutation UpdateRosterEntry($input: UpdateRosterEntryInput!, $condition: ModelRosterEntryConditionInput) {\n  updateRosterEntry(input: $input, condition: $condition) {\n    __typename\n    id\n    orgId\n    badgeNumber\n    shift\n    startsAt\n    endsAt\n    notes\n    createdAt\n    updatedAt\n  }\n}"

  public var input: UpdateRosterEntryInput
  public var condition: ModelRosterEntryConditionInput?

  public init(input: UpdateRosterEntryInput, condition: ModelRosterEntryConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("updateRosterEntry", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(UpdateRosterEntry.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(updateRosterEntry: UpdateRosterEntry? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "updateRosterEntry": updateRosterEntry.flatMap { $0.snapshot }])
    }

    public var updateRosterEntry: UpdateRosterEntry? {
      get {
        return (snapshot["updateRosterEntry"] as? Snapshot).flatMap { UpdateRosterEntry(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "updateRosterEntry")
      }
    }

    public struct UpdateRosterEntry: GraphQLSelectionSet {
      public static let possibleTypes = ["RosterEntry"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("badgeNumber", type: .nonNull(.scalar(String.self))),
        GraphQLField("shift", type: .scalar(String.self)),
        GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("notes", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, badgeNumber: String, shift: String? = nil, startsAt: String, endsAt: String, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "RosterEntry", "id": id, "orgId": orgId, "badgeNumber": badgeNumber, "shift": shift, "startsAt": startsAt, "endsAt": endsAt, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var badgeNumber: String {
        get {
          return snapshot["badgeNumber"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "badgeNumber")
        }
      }

      public var shift: String? {
        get {
          return snapshot["shift"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "shift")
        }
      }

      public var startsAt: String {
        get {
          return snapshot["startsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "startsAt")
        }
      }

      public var endsAt: String {
        get {
          return snapshot["endsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "endsAt")
        }
      }

      public var notes: String? {
        get {
          return snapshot["notes"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "notes")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class DeleteRosterEntryMutation: GraphQLMutation {
  public static let operationString =
    "mutation DeleteRosterEntry($input: DeleteRosterEntryInput!, $condition: ModelRosterEntryConditionInput) {\n  deleteRosterEntry(input: $input, condition: $condition) {\n    __typename\n    id\n    orgId\n    badgeNumber\n    shift\n    startsAt\n    endsAt\n    notes\n    createdAt\n    updatedAt\n  }\n}"

  public var input: DeleteRosterEntryInput
  public var condition: ModelRosterEntryConditionInput?

  public init(input: DeleteRosterEntryInput, condition: ModelRosterEntryConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("deleteRosterEntry", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(DeleteRosterEntry.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(deleteRosterEntry: DeleteRosterEntry? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "deleteRosterEntry": deleteRosterEntry.flatMap { $0.snapshot }])
    }

    public var deleteRosterEntry: DeleteRosterEntry? {
      get {
        return (snapshot["deleteRosterEntry"] as? Snapshot).flatMap { DeleteRosterEntry(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "deleteRosterEntry")
      }
    }

    public struct DeleteRosterEntry: GraphQLSelectionSet {
      public static let possibleTypes = ["RosterEntry"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("badgeNumber", type: .nonNull(.scalar(String.self))),
        GraphQLField("shift", type: .scalar(String.self)),
        GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("notes", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, badgeNumber: String, shift: String? = nil, startsAt: String, endsAt: String, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "RosterEntry", "id": id, "orgId": orgId, "badgeNumber": badgeNumber, "shift": shift, "startsAt": startsAt, "endsAt": endsAt, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var badgeNumber: String {
        get {
          return snapshot["badgeNumber"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "badgeNumber")
        }
      }

      public var shift: String? {
        get {
          return snapshot["shift"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "shift")
        }
      }

      public var startsAt: String {
        get {
          return snapshot["startsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "startsAt")
        }
      }

      public var endsAt: String {
        get {
          return snapshot["endsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "endsAt")
        }
      }

      public var notes: String? {
        get {
          return snapshot["notes"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "notes")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class CreateVehicleMutation: GraphQLMutation {
  public static let operationString =
    "mutation CreateVehicle($input: CreateVehicleInput!, $condition: ModelVehicleConditionInput) {\n  createVehicle(input: $input, condition: $condition) {\n    __typename\n    id\n    orgId\n    callsign\n    make\n    model\n    plate\n    inService\n    createdAt\n    updatedAt\n  }\n}"

  public var input: CreateVehicleInput
  public var condition: ModelVehicleConditionInput?

  public init(input: CreateVehicleInput, condition: ModelVehicleConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("createVehicle", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(CreateVehicle.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(createVehicle: CreateVehicle? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "createVehicle": createVehicle.flatMap { $0.snapshot }])
    }

    public var createVehicle: CreateVehicle? {
      get {
        return (snapshot["createVehicle"] as? Snapshot).flatMap { CreateVehicle(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "createVehicle")
      }
    }

    public struct CreateVehicle: GraphQLSelectionSet {
      public static let possibleTypes = ["Vehicle"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("callsign", type: .nonNull(.scalar(String.self))),
        GraphQLField("make", type: .scalar(String.self)),
        GraphQLField("model", type: .scalar(String.self)),
        GraphQLField("plate", type: .scalar(String.self)),
        GraphQLField("inService", type: .scalar(Bool.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, callsign: String, make: String? = nil, model: String? = nil, plate: String? = nil, inService: Bool? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "Vehicle", "id": id, "orgId": orgId, "callsign": callsign, "make": make, "model": model, "plate": plate, "inService": inService, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var callsign: String {
        get {
          return snapshot["callsign"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "callsign")
        }
      }

      public var make: String? {
        get {
          return snapshot["make"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "make")
        }
      }

      public var model: String? {
        get {
          return snapshot["model"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "model")
        }
      }

      public var plate: String? {
        get {
          return snapshot["plate"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "plate")
        }
      }

      public var inService: Bool? {
        get {
          return snapshot["inService"] as? Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "inService")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class UpdateVehicleMutation: GraphQLMutation {
  public static let operationString =
    "mutation UpdateVehicle($input: UpdateVehicleInput!, $condition: ModelVehicleConditionInput) {\n  updateVehicle(input: $input, condition: $condition) {\n    __typename\n    id\n    orgId\n    callsign\n    make\n    model\n    plate\n    inService\n    createdAt\n    updatedAt\n  }\n}"

  public var input: UpdateVehicleInput
  public var condition: ModelVehicleConditionInput?

  public init(input: UpdateVehicleInput, condition: ModelVehicleConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("updateVehicle", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(UpdateVehicle.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(updateVehicle: UpdateVehicle? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "updateVehicle": updateVehicle.flatMap { $0.snapshot }])
    }

    public var updateVehicle: UpdateVehicle? {
      get {
        return (snapshot["updateVehicle"] as? Snapshot).flatMap { UpdateVehicle(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "updateVehicle")
      }
    }

    public struct UpdateVehicle: GraphQLSelectionSet {
      public static let possibleTypes = ["Vehicle"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("callsign", type: .nonNull(.scalar(String.self))),
        GraphQLField("make", type: .scalar(String.self)),
        GraphQLField("model", type: .scalar(String.self)),
        GraphQLField("plate", type: .scalar(String.self)),
        GraphQLField("inService", type: .scalar(Bool.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, callsign: String, make: String? = nil, model: String? = nil, plate: String? = nil, inService: Bool? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "Vehicle", "id": id, "orgId": orgId, "callsign": callsign, "make": make, "model": model, "plate": plate, "inService": inService, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var callsign: String {
        get {
          return snapshot["callsign"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "callsign")
        }
      }

      public var make: String? {
        get {
          return snapshot["make"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "make")
        }
      }

      public var model: String? {
        get {
          return snapshot["model"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "model")
        }
      }

      public var plate: String? {
        get {
          return snapshot["plate"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "plate")
        }
      }

      public var inService: Bool? {
        get {
          return snapshot["inService"] as? Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "inService")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class DeleteVehicleMutation: GraphQLMutation {
  public static let operationString =
    "mutation DeleteVehicle($input: DeleteVehicleInput!, $condition: ModelVehicleConditionInput) {\n  deleteVehicle(input: $input, condition: $condition) {\n    __typename\n    id\n    orgId\n    callsign\n    make\n    model\n    plate\n    inService\n    createdAt\n    updatedAt\n  }\n}"

  public var input: DeleteVehicleInput
  public var condition: ModelVehicleConditionInput?

  public init(input: DeleteVehicleInput, condition: ModelVehicleConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("deleteVehicle", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(DeleteVehicle.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(deleteVehicle: DeleteVehicle? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "deleteVehicle": deleteVehicle.flatMap { $0.snapshot }])
    }

    public var deleteVehicle: DeleteVehicle? {
      get {
        return (snapshot["deleteVehicle"] as? Snapshot).flatMap { DeleteVehicle(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "deleteVehicle")
      }
    }

    public struct DeleteVehicle: GraphQLSelectionSet {
      public static let possibleTypes = ["Vehicle"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("callsign", type: .nonNull(.scalar(String.self))),
        GraphQLField("make", type: .scalar(String.self)),
        GraphQLField("model", type: .scalar(String.self)),
        GraphQLField("plate", type: .scalar(String.self)),
        GraphQLField("inService", type: .scalar(Bool.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, callsign: String, make: String? = nil, model: String? = nil, plate: String? = nil, inService: Bool? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "Vehicle", "id": id, "orgId": orgId, "callsign": callsign, "make": make, "model": model, "plate": plate, "inService": inService, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var callsign: String {
        get {
          return snapshot["callsign"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "callsign")
        }
      }

      public var make: String? {
        get {
          return snapshot["make"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "make")
        }
      }

      public var model: String? {
        get {
          return snapshot["model"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "model")
        }
      }

      public var plate: String? {
        get {
          return snapshot["plate"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "plate")
        }
      }

      public var inService: Bool? {
        get {
          return snapshot["inService"] as? Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "inService")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class CreateCalendarEventMutation: GraphQLMutation {
  public static let operationString =
    "mutation CreateCalendarEvent($input: CreateCalendarEventInput!, $condition: ModelCalendarEventConditionInput) {\n  createCalendarEvent(input: $input, condition: $condition) {\n    __typename\n    id\n    orgId\n    ownerId\n    title\n    category\n    color\n    notes\n    startsAt\n    endsAt\n    reminderMinutesBefore\n    createdAt\n    updatedAt\n  }\n}"

  public var input: CreateCalendarEventInput
  public var condition: ModelCalendarEventConditionInput?

  public init(input: CreateCalendarEventInput, condition: ModelCalendarEventConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("createCalendarEvent", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(CreateCalendarEvent.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(createCalendarEvent: CreateCalendarEvent? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "createCalendarEvent": createCalendarEvent.flatMap { $0.snapshot }])
    }

    public var createCalendarEvent: CreateCalendarEvent? {
      get {
        return (snapshot["createCalendarEvent"] as? Snapshot).flatMap { CreateCalendarEvent(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "createCalendarEvent")
      }
    }

    public struct CreateCalendarEvent: GraphQLSelectionSet {
      public static let possibleTypes = ["CalendarEvent"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("ownerId", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("category", type: .nonNull(.scalar(String.self))),
        GraphQLField("color", type: .nonNull(.scalar(String.self))),
        GraphQLField("notes", type: .scalar(String.self)),
        GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("reminderMinutesBefore", type: .scalar(Int.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, ownerId: String, title: String, category: String, color: String, notes: String? = nil, startsAt: String, endsAt: String, reminderMinutesBefore: Int? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "CalendarEvent", "id": id, "orgId": orgId, "ownerId": ownerId, "title": title, "category": category, "color": color, "notes": notes, "startsAt": startsAt, "endsAt": endsAt, "reminderMinutesBefore": reminderMinutesBefore, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var ownerId: String {
        get {
          return snapshot["ownerId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "ownerId")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var category: String {
        get {
          return snapshot["category"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "category")
        }
      }

      public var color: String {
        get {
          return snapshot["color"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "color")
        }
      }

      public var notes: String? {
        get {
          return snapshot["notes"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "notes")
        }
      }

      public var startsAt: String {
        get {
          return snapshot["startsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "startsAt")
        }
      }

      public var endsAt: String {
        get {
          return snapshot["endsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "endsAt")
        }
      }

      public var reminderMinutesBefore: Int? {
        get {
          return snapshot["reminderMinutesBefore"] as? Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "reminderMinutesBefore")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class UpdateCalendarEventMutation: GraphQLMutation {
  public static let operationString =
    "mutation UpdateCalendarEvent($input: UpdateCalendarEventInput!, $condition: ModelCalendarEventConditionInput) {\n  updateCalendarEvent(input: $input, condition: $condition) {\n    __typename\n    id\n    orgId\n    ownerId\n    title\n    category\n    color\n    notes\n    startsAt\n    endsAt\n    reminderMinutesBefore\n    createdAt\n    updatedAt\n  }\n}"

  public var input: UpdateCalendarEventInput
  public var condition: ModelCalendarEventConditionInput?

  public init(input: UpdateCalendarEventInput, condition: ModelCalendarEventConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("updateCalendarEvent", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(UpdateCalendarEvent.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(updateCalendarEvent: UpdateCalendarEvent? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "updateCalendarEvent": updateCalendarEvent.flatMap { $0.snapshot }])
    }

    public var updateCalendarEvent: UpdateCalendarEvent? {
      get {
        return (snapshot["updateCalendarEvent"] as? Snapshot).flatMap { UpdateCalendarEvent(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "updateCalendarEvent")
      }
    }

    public struct UpdateCalendarEvent: GraphQLSelectionSet {
      public static let possibleTypes = ["CalendarEvent"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("ownerId", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("category", type: .nonNull(.scalar(String.self))),
        GraphQLField("color", type: .nonNull(.scalar(String.self))),
        GraphQLField("notes", type: .scalar(String.self)),
        GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("reminderMinutesBefore", type: .scalar(Int.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, ownerId: String, title: String, category: String, color: String, notes: String? = nil, startsAt: String, endsAt: String, reminderMinutesBefore: Int? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "CalendarEvent", "id": id, "orgId": orgId, "ownerId": ownerId, "title": title, "category": category, "color": color, "notes": notes, "startsAt": startsAt, "endsAt": endsAt, "reminderMinutesBefore": reminderMinutesBefore, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var ownerId: String {
        get {
          return snapshot["ownerId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "ownerId")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var category: String {
        get {
          return snapshot["category"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "category")
        }
      }

      public var color: String {
        get {
          return snapshot["color"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "color")
        }
      }

      public var notes: String? {
        get {
          return snapshot["notes"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "notes")
        }
      }

      public var startsAt: String {
        get {
          return snapshot["startsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "startsAt")
        }
      }

      public var endsAt: String {
        get {
          return snapshot["endsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "endsAt")
        }
      }

      public var reminderMinutesBefore: Int? {
        get {
          return snapshot["reminderMinutesBefore"] as? Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "reminderMinutesBefore")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class DeleteCalendarEventMutation: GraphQLMutation {
  public static let operationString =
    "mutation DeleteCalendarEvent($input: DeleteCalendarEventInput!, $condition: ModelCalendarEventConditionInput) {\n  deleteCalendarEvent(input: $input, condition: $condition) {\n    __typename\n    id\n    orgId\n    ownerId\n    title\n    category\n    color\n    notes\n    startsAt\n    endsAt\n    reminderMinutesBefore\n    createdAt\n    updatedAt\n  }\n}"

  public var input: DeleteCalendarEventInput
  public var condition: ModelCalendarEventConditionInput?

  public init(input: DeleteCalendarEventInput, condition: ModelCalendarEventConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("deleteCalendarEvent", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(DeleteCalendarEvent.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(deleteCalendarEvent: DeleteCalendarEvent? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "deleteCalendarEvent": deleteCalendarEvent.flatMap { $0.snapshot }])
    }

    public var deleteCalendarEvent: DeleteCalendarEvent? {
      get {
        return (snapshot["deleteCalendarEvent"] as? Snapshot).flatMap { DeleteCalendarEvent(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "deleteCalendarEvent")
      }
    }

    public struct DeleteCalendarEvent: GraphQLSelectionSet {
      public static let possibleTypes = ["CalendarEvent"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("ownerId", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("category", type: .nonNull(.scalar(String.self))),
        GraphQLField("color", type: .nonNull(.scalar(String.self))),
        GraphQLField("notes", type: .scalar(String.self)),
        GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("reminderMinutesBefore", type: .scalar(Int.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, ownerId: String, title: String, category: String, color: String, notes: String? = nil, startsAt: String, endsAt: String, reminderMinutesBefore: Int? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "CalendarEvent", "id": id, "orgId": orgId, "ownerId": ownerId, "title": title, "category": category, "color": color, "notes": notes, "startsAt": startsAt, "endsAt": endsAt, "reminderMinutesBefore": reminderMinutesBefore, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var ownerId: String {
        get {
          return snapshot["ownerId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "ownerId")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var category: String {
        get {
          return snapshot["category"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "category")
        }
      }

      public var color: String {
        get {
          return snapshot["color"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "color")
        }
      }

      public var notes: String? {
        get {
          return snapshot["notes"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "notes")
        }
      }

      public var startsAt: String {
        get {
          return snapshot["startsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "startsAt")
        }
      }

      public var endsAt: String {
        get {
          return snapshot["endsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "endsAt")
        }
      }

      public var reminderMinutesBefore: Int? {
        get {
          return snapshot["reminderMinutesBefore"] as? Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "reminderMinutesBefore")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class CreateOfficerAssignmentMutation: GraphQLMutation {
  public static let operationString =
    "mutation CreateOfficerAssignment($input: CreateOfficerAssignmentInput!, $condition: ModelOfficerAssignmentConditionInput) {\n  createOfficerAssignment(input: $input, condition: $condition) {\n    __typename\n    id\n    orgId\n    badgeNumber\n    title\n    detail\n    location\n    notes\n    createdAt\n    updatedAt\n  }\n}"

  public var input: CreateOfficerAssignmentInput
  public var condition: ModelOfficerAssignmentConditionInput?

  public init(input: CreateOfficerAssignmentInput, condition: ModelOfficerAssignmentConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("createOfficerAssignment", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(CreateOfficerAssignment.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(createOfficerAssignment: CreateOfficerAssignment? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "createOfficerAssignment": createOfficerAssignment.flatMap { $0.snapshot }])
    }

    public var createOfficerAssignment: CreateOfficerAssignment? {
      get {
        return (snapshot["createOfficerAssignment"] as? Snapshot).flatMap { CreateOfficerAssignment(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "createOfficerAssignment")
      }
    }

    public struct CreateOfficerAssignment: GraphQLSelectionSet {
      public static let possibleTypes = ["OfficerAssignment"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("badgeNumber", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("detail", type: .scalar(String.self)),
        GraphQLField("location", type: .scalar(String.self)),
        GraphQLField("notes", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, badgeNumber: String, title: String, detail: String? = nil, location: String? = nil, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "OfficerAssignment", "id": id, "orgId": orgId, "badgeNumber": badgeNumber, "title": title, "detail": detail, "location": location, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var badgeNumber: String {
        get {
          return snapshot["badgeNumber"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "badgeNumber")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var detail: String? {
        get {
          return snapshot["detail"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "detail")
        }
      }

      public var location: String? {
        get {
          return snapshot["location"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "location")
        }
      }

      public var notes: String? {
        get {
          return snapshot["notes"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "notes")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class UpdateOfficerAssignmentMutation: GraphQLMutation {
  public static let operationString =
    "mutation UpdateOfficerAssignment($input: UpdateOfficerAssignmentInput!, $condition: ModelOfficerAssignmentConditionInput) {\n  updateOfficerAssignment(input: $input, condition: $condition) {\n    __typename\n    id\n    orgId\n    badgeNumber\n    title\n    detail\n    location\n    notes\n    createdAt\n    updatedAt\n  }\n}"

  public var input: UpdateOfficerAssignmentInput
  public var condition: ModelOfficerAssignmentConditionInput?

  public init(input: UpdateOfficerAssignmentInput, condition: ModelOfficerAssignmentConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("updateOfficerAssignment", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(UpdateOfficerAssignment.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(updateOfficerAssignment: UpdateOfficerAssignment? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "updateOfficerAssignment": updateOfficerAssignment.flatMap { $0.snapshot }])
    }

    public var updateOfficerAssignment: UpdateOfficerAssignment? {
      get {
        return (snapshot["updateOfficerAssignment"] as? Snapshot).flatMap { UpdateOfficerAssignment(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "updateOfficerAssignment")
      }
    }

    public struct UpdateOfficerAssignment: GraphQLSelectionSet {
      public static let possibleTypes = ["OfficerAssignment"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("badgeNumber", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("detail", type: .scalar(String.self)),
        GraphQLField("location", type: .scalar(String.self)),
        GraphQLField("notes", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, badgeNumber: String, title: String, detail: String? = nil, location: String? = nil, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "OfficerAssignment", "id": id, "orgId": orgId, "badgeNumber": badgeNumber, "title": title, "detail": detail, "location": location, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var badgeNumber: String {
        get {
          return snapshot["badgeNumber"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "badgeNumber")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var detail: String? {
        get {
          return snapshot["detail"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "detail")
        }
      }

      public var location: String? {
        get {
          return snapshot["location"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "location")
        }
      }

      public var notes: String? {
        get {
          return snapshot["notes"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "notes")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class DeleteOfficerAssignmentMutation: GraphQLMutation {
  public static let operationString =
    "mutation DeleteOfficerAssignment($input: DeleteOfficerAssignmentInput!, $condition: ModelOfficerAssignmentConditionInput) {\n  deleteOfficerAssignment(input: $input, condition: $condition) {\n    __typename\n    id\n    orgId\n    badgeNumber\n    title\n    detail\n    location\n    notes\n    createdAt\n    updatedAt\n  }\n}"

  public var input: DeleteOfficerAssignmentInput
  public var condition: ModelOfficerAssignmentConditionInput?

  public init(input: DeleteOfficerAssignmentInput, condition: ModelOfficerAssignmentConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("deleteOfficerAssignment", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(DeleteOfficerAssignment.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(deleteOfficerAssignment: DeleteOfficerAssignment? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "deleteOfficerAssignment": deleteOfficerAssignment.flatMap { $0.snapshot }])
    }

    public var deleteOfficerAssignment: DeleteOfficerAssignment? {
      get {
        return (snapshot["deleteOfficerAssignment"] as? Snapshot).flatMap { DeleteOfficerAssignment(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "deleteOfficerAssignment")
      }
    }

    public struct DeleteOfficerAssignment: GraphQLSelectionSet {
      public static let possibleTypes = ["OfficerAssignment"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("badgeNumber", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("detail", type: .scalar(String.self)),
        GraphQLField("location", type: .scalar(String.self)),
        GraphQLField("notes", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, badgeNumber: String, title: String, detail: String? = nil, location: String? = nil, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "OfficerAssignment", "id": id, "orgId": orgId, "badgeNumber": badgeNumber, "title": title, "detail": detail, "location": location, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var badgeNumber: String {
        get {
          return snapshot["badgeNumber"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "badgeNumber")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var detail: String? {
        get {
          return snapshot["detail"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "detail")
        }
      }

      public var location: String? {
        get {
          return snapshot["location"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "location")
        }
      }

      public var notes: String? {
        get {
          return snapshot["notes"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "notes")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class CreateOvertimePostingMutation: GraphQLMutation {
  public static let operationString =
    "mutation CreateOvertimePosting($input: CreateOvertimePostingInput!, $condition: ModelOvertimePostingConditionInput) {\n  createOvertimePosting(input: $input, condition: $condition) {\n    __typename\n    id\n    orgId\n    title\n    location\n    scenario\n    startsAt\n    endsAt\n    slots\n    policySnapshot\n    selectionPolicy\n    needsEscalation\n    state\n    createdBy\n    invites {\n      __typename\n      nextToken\n    }\n    auditTrail {\n      __typename\n      nextToken\n    }\n    createdAt\n    updatedAt\n  }\n}"

  public var input: CreateOvertimePostingInput
  public var condition: ModelOvertimePostingConditionInput?

  public init(input: CreateOvertimePostingInput, condition: ModelOvertimePostingConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("createOvertimePosting", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(CreateOvertimePosting.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(createOvertimePosting: CreateOvertimePosting? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "createOvertimePosting": createOvertimePosting.flatMap { $0.snapshot }])
    }

    public var createOvertimePosting: CreateOvertimePosting? {
      get {
        return (snapshot["createOvertimePosting"] as? Snapshot).flatMap { CreateOvertimePosting(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "createOvertimePosting")
      }
    }

    public struct CreateOvertimePosting: GraphQLSelectionSet {
      public static let possibleTypes = ["OvertimePosting"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("location", type: .scalar(String.self)),
        GraphQLField("scenario", type: .nonNull(.scalar(OvertimeScenario.self))),
        GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("slots", type: .nonNull(.scalar(Int.self))),
        GraphQLField("policySnapshot", type: .nonNull(.scalar(String.self))),
        GraphQLField("selectionPolicy", type: .scalar(OvertimeSelectionPolicy.self)),
        GraphQLField("needsEscalation", type: .scalar(Bool.self)),
        GraphQLField("state", type: .nonNull(.scalar(OvertimePostingState.self))),
        GraphQLField("createdBy", type: .nonNull(.scalar(String.self))),
        GraphQLField("invites", type: .object(Invite.selections)),
        GraphQLField("auditTrail", type: .object(AuditTrail.selections)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, title: String, location: String? = nil, scenario: OvertimeScenario, startsAt: String, endsAt: String, slots: Int, policySnapshot: String, selectionPolicy: OvertimeSelectionPolicy? = nil, needsEscalation: Bool? = nil, state: OvertimePostingState, createdBy: String, invites: Invite? = nil, auditTrail: AuditTrail? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "OvertimePosting", "id": id, "orgId": orgId, "title": title, "location": location, "scenario": scenario, "startsAt": startsAt, "endsAt": endsAt, "slots": slots, "policySnapshot": policySnapshot, "selectionPolicy": selectionPolicy, "needsEscalation": needsEscalation, "state": state, "createdBy": createdBy, "invites": invites.flatMap { $0.snapshot }, "auditTrail": auditTrail.flatMap { $0.snapshot }, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var location: String? {
        get {
          return snapshot["location"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "location")
        }
      }

      public var scenario: OvertimeScenario {
        get {
          return snapshot["scenario"]! as! OvertimeScenario
        }
        set {
          snapshot.updateValue(newValue, forKey: "scenario")
        }
      }

      public var startsAt: String {
        get {
          return snapshot["startsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "startsAt")
        }
      }

      public var endsAt: String {
        get {
          return snapshot["endsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "endsAt")
        }
      }

      public var slots: Int {
        get {
          return snapshot["slots"]! as! Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "slots")
        }
      }

      public var policySnapshot: String {
        get {
          return snapshot["policySnapshot"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "policySnapshot")
        }
      }

      public var selectionPolicy: OvertimeSelectionPolicy? {
        get {
          return snapshot["selectionPolicy"] as? OvertimeSelectionPolicy
        }
        set {
          snapshot.updateValue(newValue, forKey: "selectionPolicy")
        }
      }

      public var needsEscalation: Bool? {
        get {
          return snapshot["needsEscalation"] as? Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "needsEscalation")
        }
      }

      public var state: OvertimePostingState {
        get {
          return snapshot["state"]! as! OvertimePostingState
        }
        set {
          snapshot.updateValue(newValue, forKey: "state")
        }
      }

      public var createdBy: String {
        get {
          return snapshot["createdBy"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdBy")
        }
      }

      public var invites: Invite? {
        get {
          return (snapshot["invites"] as? Snapshot).flatMap { Invite(snapshot: $0) }
        }
        set {
          snapshot.updateValue(newValue?.snapshot, forKey: "invites")
        }
      }

      public var auditTrail: AuditTrail? {
        get {
          return (snapshot["auditTrail"] as? Snapshot).flatMap { AuditTrail(snapshot: $0) }
        }
        set {
          snapshot.updateValue(newValue?.snapshot, forKey: "auditTrail")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }

      public struct Invite: GraphQLSelectionSet {
        public static let possibleTypes = ["ModelOvertimeInviteConnection"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("nextToken", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(nextToken: String? = nil) {
          self.init(snapshot: ["__typename": "ModelOvertimeInviteConnection", "nextToken": nextToken])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var nextToken: String? {
          get {
            return snapshot["nextToken"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "nextToken")
          }
        }
      }

      public struct AuditTrail: GraphQLSelectionSet {
        public static let possibleTypes = ["ModelOvertimeAuditEventConnection"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("nextToken", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(nextToken: String? = nil) {
          self.init(snapshot: ["__typename": "ModelOvertimeAuditEventConnection", "nextToken": nextToken])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var nextToken: String? {
          get {
            return snapshot["nextToken"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "nextToken")
          }
        }
      }
    }
  }
}

public final class UpdateOvertimePostingMutation: GraphQLMutation {
  public static let operationString =
    "mutation UpdateOvertimePosting($input: UpdateOvertimePostingInput!, $condition: ModelOvertimePostingConditionInput) {\n  updateOvertimePosting(input: $input, condition: $condition) {\n    __typename\n    id\n    orgId\n    title\n    location\n    scenario\n    startsAt\n    endsAt\n    slots\n    policySnapshot\n    selectionPolicy\n    needsEscalation\n    state\n    createdBy\n    invites {\n      __typename\n      nextToken\n    }\n    auditTrail {\n      __typename\n      nextToken\n    }\n    createdAt\n    updatedAt\n  }\n}"

  public var input: UpdateOvertimePostingInput
  public var condition: ModelOvertimePostingConditionInput?

  public init(input: UpdateOvertimePostingInput, condition: ModelOvertimePostingConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("updateOvertimePosting", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(UpdateOvertimePosting.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(updateOvertimePosting: UpdateOvertimePosting? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "updateOvertimePosting": updateOvertimePosting.flatMap { $0.snapshot }])
    }

    public var updateOvertimePosting: UpdateOvertimePosting? {
      get {
        return (snapshot["updateOvertimePosting"] as? Snapshot).flatMap { UpdateOvertimePosting(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "updateOvertimePosting")
      }
    }

    public struct UpdateOvertimePosting: GraphQLSelectionSet {
      public static let possibleTypes = ["OvertimePosting"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("location", type: .scalar(String.self)),
        GraphQLField("scenario", type: .nonNull(.scalar(OvertimeScenario.self))),
        GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("slots", type: .nonNull(.scalar(Int.self))),
        GraphQLField("policySnapshot", type: .nonNull(.scalar(String.self))),
        GraphQLField("selectionPolicy", type: .scalar(OvertimeSelectionPolicy.self)),
        GraphQLField("needsEscalation", type: .scalar(Bool.self)),
        GraphQLField("state", type: .nonNull(.scalar(OvertimePostingState.self))),
        GraphQLField("createdBy", type: .nonNull(.scalar(String.self))),
        GraphQLField("invites", type: .object(Invite.selections)),
        GraphQLField("auditTrail", type: .object(AuditTrail.selections)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, title: String, location: String? = nil, scenario: OvertimeScenario, startsAt: String, endsAt: String, slots: Int, policySnapshot: String, selectionPolicy: OvertimeSelectionPolicy? = nil, needsEscalation: Bool? = nil, state: OvertimePostingState, createdBy: String, invites: Invite? = nil, auditTrail: AuditTrail? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "OvertimePosting", "id": id, "orgId": orgId, "title": title, "location": location, "scenario": scenario, "startsAt": startsAt, "endsAt": endsAt, "slots": slots, "policySnapshot": policySnapshot, "selectionPolicy": selectionPolicy, "needsEscalation": needsEscalation, "state": state, "createdBy": createdBy, "invites": invites.flatMap { $0.snapshot }, "auditTrail": auditTrail.flatMap { $0.snapshot }, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var location: String? {
        get {
          return snapshot["location"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "location")
        }
      }

      public var scenario: OvertimeScenario {
        get {
          return snapshot["scenario"]! as! OvertimeScenario
        }
        set {
          snapshot.updateValue(newValue, forKey: "scenario")
        }
      }

      public var startsAt: String {
        get {
          return snapshot["startsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "startsAt")
        }
      }

      public var endsAt: String {
        get {
          return snapshot["endsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "endsAt")
        }
      }

      public var slots: Int {
        get {
          return snapshot["slots"]! as! Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "slots")
        }
      }

      public var policySnapshot: String {
        get {
          return snapshot["policySnapshot"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "policySnapshot")
        }
      }

      public var selectionPolicy: OvertimeSelectionPolicy? {
        get {
          return snapshot["selectionPolicy"] as? OvertimeSelectionPolicy
        }
        set {
          snapshot.updateValue(newValue, forKey: "selectionPolicy")
        }
      }

      public var needsEscalation: Bool? {
        get {
          return snapshot["needsEscalation"] as? Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "needsEscalation")
        }
      }

      public var state: OvertimePostingState {
        get {
          return snapshot["state"]! as! OvertimePostingState
        }
        set {
          snapshot.updateValue(newValue, forKey: "state")
        }
      }

      public var createdBy: String {
        get {
          return snapshot["createdBy"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdBy")
        }
      }

      public var invites: Invite? {
        get {
          return (snapshot["invites"] as? Snapshot).flatMap { Invite(snapshot: $0) }
        }
        set {
          snapshot.updateValue(newValue?.snapshot, forKey: "invites")
        }
      }

      public var auditTrail: AuditTrail? {
        get {
          return (snapshot["auditTrail"] as? Snapshot).flatMap { AuditTrail(snapshot: $0) }
        }
        set {
          snapshot.updateValue(newValue?.snapshot, forKey: "auditTrail")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }

      public struct Invite: GraphQLSelectionSet {
        public static let possibleTypes = ["ModelOvertimeInviteConnection"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("nextToken", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(nextToken: String? = nil) {
          self.init(snapshot: ["__typename": "ModelOvertimeInviteConnection", "nextToken": nextToken])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var nextToken: String? {
          get {
            return snapshot["nextToken"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "nextToken")
          }
        }
      }

      public struct AuditTrail: GraphQLSelectionSet {
        public static let possibleTypes = ["ModelOvertimeAuditEventConnection"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("nextToken", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(nextToken: String? = nil) {
          self.init(snapshot: ["__typename": "ModelOvertimeAuditEventConnection", "nextToken": nextToken])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var nextToken: String? {
          get {
            return snapshot["nextToken"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "nextToken")
          }
        }
      }
    }
  }
}

public final class DeleteOvertimePostingMutation: GraphQLMutation {
  public static let operationString =
    "mutation DeleteOvertimePosting($input: DeleteOvertimePostingInput!, $condition: ModelOvertimePostingConditionInput) {\n  deleteOvertimePosting(input: $input, condition: $condition) {\n    __typename\n    id\n    orgId\n    title\n    location\n    scenario\n    startsAt\n    endsAt\n    slots\n    policySnapshot\n    selectionPolicy\n    needsEscalation\n    state\n    createdBy\n    invites {\n      __typename\n      nextToken\n    }\n    auditTrail {\n      __typename\n      nextToken\n    }\n    createdAt\n    updatedAt\n  }\n}"

  public var input: DeleteOvertimePostingInput
  public var condition: ModelOvertimePostingConditionInput?

  public init(input: DeleteOvertimePostingInput, condition: ModelOvertimePostingConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("deleteOvertimePosting", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(DeleteOvertimePosting.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(deleteOvertimePosting: DeleteOvertimePosting? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "deleteOvertimePosting": deleteOvertimePosting.flatMap { $0.snapshot }])
    }

    public var deleteOvertimePosting: DeleteOvertimePosting? {
      get {
        return (snapshot["deleteOvertimePosting"] as? Snapshot).flatMap { DeleteOvertimePosting(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "deleteOvertimePosting")
      }
    }

    public struct DeleteOvertimePosting: GraphQLSelectionSet {
      public static let possibleTypes = ["OvertimePosting"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("location", type: .scalar(String.self)),
        GraphQLField("scenario", type: .nonNull(.scalar(OvertimeScenario.self))),
        GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("slots", type: .nonNull(.scalar(Int.self))),
        GraphQLField("policySnapshot", type: .nonNull(.scalar(String.self))),
        GraphQLField("selectionPolicy", type: .scalar(OvertimeSelectionPolicy.self)),
        GraphQLField("needsEscalation", type: .scalar(Bool.self)),
        GraphQLField("state", type: .nonNull(.scalar(OvertimePostingState.self))),
        GraphQLField("createdBy", type: .nonNull(.scalar(String.self))),
        GraphQLField("invites", type: .object(Invite.selections)),
        GraphQLField("auditTrail", type: .object(AuditTrail.selections)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, title: String, location: String? = nil, scenario: OvertimeScenario, startsAt: String, endsAt: String, slots: Int, policySnapshot: String, selectionPolicy: OvertimeSelectionPolicy? = nil, needsEscalation: Bool? = nil, state: OvertimePostingState, createdBy: String, invites: Invite? = nil, auditTrail: AuditTrail? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "OvertimePosting", "id": id, "orgId": orgId, "title": title, "location": location, "scenario": scenario, "startsAt": startsAt, "endsAt": endsAt, "slots": slots, "policySnapshot": policySnapshot, "selectionPolicy": selectionPolicy, "needsEscalation": needsEscalation, "state": state, "createdBy": createdBy, "invites": invites.flatMap { $0.snapshot }, "auditTrail": auditTrail.flatMap { $0.snapshot }, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var location: String? {
        get {
          return snapshot["location"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "location")
        }
      }

      public var scenario: OvertimeScenario {
        get {
          return snapshot["scenario"]! as! OvertimeScenario
        }
        set {
          snapshot.updateValue(newValue, forKey: "scenario")
        }
      }

      public var startsAt: String {
        get {
          return snapshot["startsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "startsAt")
        }
      }

      public var endsAt: String {
        get {
          return snapshot["endsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "endsAt")
        }
      }

      public var slots: Int {
        get {
          return snapshot["slots"]! as! Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "slots")
        }
      }

      public var policySnapshot: String {
        get {
          return snapshot["policySnapshot"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "policySnapshot")
        }
      }

      public var selectionPolicy: OvertimeSelectionPolicy? {
        get {
          return snapshot["selectionPolicy"] as? OvertimeSelectionPolicy
        }
        set {
          snapshot.updateValue(newValue, forKey: "selectionPolicy")
        }
      }

      public var needsEscalation: Bool? {
        get {
          return snapshot["needsEscalation"] as? Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "needsEscalation")
        }
      }

      public var state: OvertimePostingState {
        get {
          return snapshot["state"]! as! OvertimePostingState
        }
        set {
          snapshot.updateValue(newValue, forKey: "state")
        }
      }

      public var createdBy: String {
        get {
          return snapshot["createdBy"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdBy")
        }
      }

      public var invites: Invite? {
        get {
          return (snapshot["invites"] as? Snapshot).flatMap { Invite(snapshot: $0) }
        }
        set {
          snapshot.updateValue(newValue?.snapshot, forKey: "invites")
        }
      }

      public var auditTrail: AuditTrail? {
        get {
          return (snapshot["auditTrail"] as? Snapshot).flatMap { AuditTrail(snapshot: $0) }
        }
        set {
          snapshot.updateValue(newValue?.snapshot, forKey: "auditTrail")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }

      public struct Invite: GraphQLSelectionSet {
        public static let possibleTypes = ["ModelOvertimeInviteConnection"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("nextToken", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(nextToken: String? = nil) {
          self.init(snapshot: ["__typename": "ModelOvertimeInviteConnection", "nextToken": nextToken])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var nextToken: String? {
          get {
            return snapshot["nextToken"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "nextToken")
          }
        }
      }

      public struct AuditTrail: GraphQLSelectionSet {
        public static let possibleTypes = ["ModelOvertimeAuditEventConnection"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("nextToken", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(nextToken: String? = nil) {
          self.init(snapshot: ["__typename": "ModelOvertimeAuditEventConnection", "nextToken": nextToken])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var nextToken: String? {
          get {
            return snapshot["nextToken"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "nextToken")
          }
        }
      }
    }
  }
}

public final class CreateOvertimeInviteMutation: GraphQLMutation {
  public static let operationString =
    "mutation CreateOvertimeInvite($input: CreateOvertimeInviteInput!, $condition: ModelOvertimeInviteConditionInput) {\n  createOvertimeInvite(input: $input, condition: $condition) {\n    __typename\n    id\n    postingId\n    officerId\n    bucket\n    sequence\n    reason\n    status\n    respondedAt\n    createdAt\n    updatedAt\n  }\n}"

  public var input: CreateOvertimeInviteInput
  public var condition: ModelOvertimeInviteConditionInput?

  public init(input: CreateOvertimeInviteInput, condition: ModelOvertimeInviteConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("createOvertimeInvite", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(CreateOvertimeInvite.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(createOvertimeInvite: CreateOvertimeInvite? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "createOvertimeInvite": createOvertimeInvite.flatMap { $0.snapshot }])
    }

    public var createOvertimeInvite: CreateOvertimeInvite? {
      get {
        return (snapshot["createOvertimeInvite"] as? Snapshot).flatMap { CreateOvertimeInvite(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "createOvertimeInvite")
      }
    }

    public struct CreateOvertimeInvite: GraphQLSelectionSet {
      public static let possibleTypes = ["OvertimeInvite"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("postingId", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("officerId", type: .nonNull(.scalar(String.self))),
        GraphQLField("bucket", type: .nonNull(.scalar(String.self))),
        GraphQLField("sequence", type: .nonNull(.scalar(Int.self))),
        GraphQLField("reason", type: .nonNull(.scalar(String.self))),
        GraphQLField("status", type: .nonNull(.scalar(OvertimeInviteStatus.self))),
        GraphQLField("respondedAt", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, postingId: GraphQLID, officerId: String, bucket: String, sequence: Int, reason: String, status: OvertimeInviteStatus, respondedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "OvertimeInvite", "id": id, "postingId": postingId, "officerId": officerId, "bucket": bucket, "sequence": sequence, "reason": reason, "status": status, "respondedAt": respondedAt, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var postingId: GraphQLID {
        get {
          return snapshot["postingId"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "postingId")
        }
      }

      public var officerId: String {
        get {
          return snapshot["officerId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "officerId")
        }
      }

      public var bucket: String {
        get {
          return snapshot["bucket"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "bucket")
        }
      }

      public var sequence: Int {
        get {
          return snapshot["sequence"]! as! Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "sequence")
        }
      }

      public var reason: String {
        get {
          return snapshot["reason"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "reason")
        }
      }

      public var status: OvertimeInviteStatus {
        get {
          return snapshot["status"]! as! OvertimeInviteStatus
        }
        set {
          snapshot.updateValue(newValue, forKey: "status")
        }
      }

      public var respondedAt: String? {
        get {
          return snapshot["respondedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "respondedAt")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class UpdateOvertimeInviteMutation: GraphQLMutation {
  public static let operationString =
    "mutation UpdateOvertimeInvite($input: UpdateOvertimeInviteInput!, $condition: ModelOvertimeInviteConditionInput) {\n  updateOvertimeInvite(input: $input, condition: $condition) {\n    __typename\n    id\n    postingId\n    officerId\n    bucket\n    sequence\n    reason\n    status\n    respondedAt\n    createdAt\n    updatedAt\n  }\n}"

  public var input: UpdateOvertimeInviteInput
  public var condition: ModelOvertimeInviteConditionInput?

  public init(input: UpdateOvertimeInviteInput, condition: ModelOvertimeInviteConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("updateOvertimeInvite", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(UpdateOvertimeInvite.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(updateOvertimeInvite: UpdateOvertimeInvite? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "updateOvertimeInvite": updateOvertimeInvite.flatMap { $0.snapshot }])
    }

    public var updateOvertimeInvite: UpdateOvertimeInvite? {
      get {
        return (snapshot["updateOvertimeInvite"] as? Snapshot).flatMap { UpdateOvertimeInvite(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "updateOvertimeInvite")
      }
    }

    public struct UpdateOvertimeInvite: GraphQLSelectionSet {
      public static let possibleTypes = ["OvertimeInvite"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("postingId", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("officerId", type: .nonNull(.scalar(String.self))),
        GraphQLField("bucket", type: .nonNull(.scalar(String.self))),
        GraphQLField("sequence", type: .nonNull(.scalar(Int.self))),
        GraphQLField("reason", type: .nonNull(.scalar(String.self))),
        GraphQLField("status", type: .nonNull(.scalar(OvertimeInviteStatus.self))),
        GraphQLField("respondedAt", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, postingId: GraphQLID, officerId: String, bucket: String, sequence: Int, reason: String, status: OvertimeInviteStatus, respondedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "OvertimeInvite", "id": id, "postingId": postingId, "officerId": officerId, "bucket": bucket, "sequence": sequence, "reason": reason, "status": status, "respondedAt": respondedAt, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var postingId: GraphQLID {
        get {
          return snapshot["postingId"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "postingId")
        }
      }

      public var officerId: String {
        get {
          return snapshot["officerId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "officerId")
        }
      }

      public var bucket: String {
        get {
          return snapshot["bucket"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "bucket")
        }
      }

      public var sequence: Int {
        get {
          return snapshot["sequence"]! as! Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "sequence")
        }
      }

      public var reason: String {
        get {
          return snapshot["reason"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "reason")
        }
      }

      public var status: OvertimeInviteStatus {
        get {
          return snapshot["status"]! as! OvertimeInviteStatus
        }
        set {
          snapshot.updateValue(newValue, forKey: "status")
        }
      }

      public var respondedAt: String? {
        get {
          return snapshot["respondedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "respondedAt")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class DeleteOvertimeInviteMutation: GraphQLMutation {
  public static let operationString =
    "mutation DeleteOvertimeInvite($input: DeleteOvertimeInviteInput!, $condition: ModelOvertimeInviteConditionInput) {\n  deleteOvertimeInvite(input: $input, condition: $condition) {\n    __typename\n    id\n    postingId\n    officerId\n    bucket\n    sequence\n    reason\n    status\n    respondedAt\n    createdAt\n    updatedAt\n  }\n}"

  public var input: DeleteOvertimeInviteInput
  public var condition: ModelOvertimeInviteConditionInput?

  public init(input: DeleteOvertimeInviteInput, condition: ModelOvertimeInviteConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("deleteOvertimeInvite", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(DeleteOvertimeInvite.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(deleteOvertimeInvite: DeleteOvertimeInvite? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "deleteOvertimeInvite": deleteOvertimeInvite.flatMap { $0.snapshot }])
    }

    public var deleteOvertimeInvite: DeleteOvertimeInvite? {
      get {
        return (snapshot["deleteOvertimeInvite"] as? Snapshot).flatMap { DeleteOvertimeInvite(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "deleteOvertimeInvite")
      }
    }

    public struct DeleteOvertimeInvite: GraphQLSelectionSet {
      public static let possibleTypes = ["OvertimeInvite"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("postingId", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("officerId", type: .nonNull(.scalar(String.self))),
        GraphQLField("bucket", type: .nonNull(.scalar(String.self))),
        GraphQLField("sequence", type: .nonNull(.scalar(Int.self))),
        GraphQLField("reason", type: .nonNull(.scalar(String.self))),
        GraphQLField("status", type: .nonNull(.scalar(OvertimeInviteStatus.self))),
        GraphQLField("respondedAt", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, postingId: GraphQLID, officerId: String, bucket: String, sequence: Int, reason: String, status: OvertimeInviteStatus, respondedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "OvertimeInvite", "id": id, "postingId": postingId, "officerId": officerId, "bucket": bucket, "sequence": sequence, "reason": reason, "status": status, "respondedAt": respondedAt, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var postingId: GraphQLID {
        get {
          return snapshot["postingId"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "postingId")
        }
      }

      public var officerId: String {
        get {
          return snapshot["officerId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "officerId")
        }
      }

      public var bucket: String {
        get {
          return snapshot["bucket"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "bucket")
        }
      }

      public var sequence: Int {
        get {
          return snapshot["sequence"]! as! Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "sequence")
        }
      }

      public var reason: String {
        get {
          return snapshot["reason"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "reason")
        }
      }

      public var status: OvertimeInviteStatus {
        get {
          return snapshot["status"]! as! OvertimeInviteStatus
        }
        set {
          snapshot.updateValue(newValue, forKey: "status")
        }
      }

      public var respondedAt: String? {
        get {
          return snapshot["respondedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "respondedAt")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class CreateOvertimeAuditEventMutation: GraphQLMutation {
  public static let operationString =
    "mutation CreateOvertimeAuditEvent($input: CreateOvertimeAuditEventInput!, $condition: ModelOvertimeAuditEventConditionInput) {\n  createOvertimeAuditEvent(input: $input, condition: $condition) {\n    __typename\n    id\n    postingId\n    type\n    details\n    createdBy\n    createdAt\n    updatedAt\n  }\n}"

  public var input: CreateOvertimeAuditEventInput
  public var condition: ModelOvertimeAuditEventConditionInput?

  public init(input: CreateOvertimeAuditEventInput, condition: ModelOvertimeAuditEventConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("createOvertimeAuditEvent", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(CreateOvertimeAuditEvent.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(createOvertimeAuditEvent: CreateOvertimeAuditEvent? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "createOvertimeAuditEvent": createOvertimeAuditEvent.flatMap { $0.snapshot }])
    }

    public var createOvertimeAuditEvent: CreateOvertimeAuditEvent? {
      get {
        return (snapshot["createOvertimeAuditEvent"] as? Snapshot).flatMap { CreateOvertimeAuditEvent(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "createOvertimeAuditEvent")
      }
    }

    public struct CreateOvertimeAuditEvent: GraphQLSelectionSet {
      public static let possibleTypes = ["OvertimeAuditEvent"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("postingId", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("type", type: .nonNull(.scalar(String.self))),
        GraphQLField("details", type: .scalar(String.self)),
        GraphQLField("createdBy", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .nonNull(.scalar(String.self))),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, postingId: GraphQLID, type: String, details: String? = nil, createdBy: String? = nil, createdAt: String? = nil, updatedAt: String) {
        self.init(snapshot: ["__typename": "OvertimeAuditEvent", "id": id, "postingId": postingId, "type": type, "details": details, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var postingId: GraphQLID {
        get {
          return snapshot["postingId"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "postingId")
        }
      }

      public var type: String {
        get {
          return snapshot["type"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "type")
        }
      }

      public var details: String? {
        get {
          return snapshot["details"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "details")
        }
      }

      public var createdBy: String? {
        get {
          return snapshot["createdBy"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdBy")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String {
        get {
          return snapshot["updatedAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class UpdateOvertimeAuditEventMutation: GraphQLMutation {
  public static let operationString =
    "mutation UpdateOvertimeAuditEvent($input: UpdateOvertimeAuditEventInput!, $condition: ModelOvertimeAuditEventConditionInput) {\n  updateOvertimeAuditEvent(input: $input, condition: $condition) {\n    __typename\n    id\n    postingId\n    type\n    details\n    createdBy\n    createdAt\n    updatedAt\n  }\n}"

  public var input: UpdateOvertimeAuditEventInput
  public var condition: ModelOvertimeAuditEventConditionInput?

  public init(input: UpdateOvertimeAuditEventInput, condition: ModelOvertimeAuditEventConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("updateOvertimeAuditEvent", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(UpdateOvertimeAuditEvent.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(updateOvertimeAuditEvent: UpdateOvertimeAuditEvent? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "updateOvertimeAuditEvent": updateOvertimeAuditEvent.flatMap { $0.snapshot }])
    }

    public var updateOvertimeAuditEvent: UpdateOvertimeAuditEvent? {
      get {
        return (snapshot["updateOvertimeAuditEvent"] as? Snapshot).flatMap { UpdateOvertimeAuditEvent(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "updateOvertimeAuditEvent")
      }
    }

    public struct UpdateOvertimeAuditEvent: GraphQLSelectionSet {
      public static let possibleTypes = ["OvertimeAuditEvent"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("postingId", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("type", type: .nonNull(.scalar(String.self))),
        GraphQLField("details", type: .scalar(String.self)),
        GraphQLField("createdBy", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .nonNull(.scalar(String.self))),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, postingId: GraphQLID, type: String, details: String? = nil, createdBy: String? = nil, createdAt: String? = nil, updatedAt: String) {
        self.init(snapshot: ["__typename": "OvertimeAuditEvent", "id": id, "postingId": postingId, "type": type, "details": details, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var postingId: GraphQLID {
        get {
          return snapshot["postingId"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "postingId")
        }
      }

      public var type: String {
        get {
          return snapshot["type"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "type")
        }
      }

      public var details: String? {
        get {
          return snapshot["details"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "details")
        }
      }

      public var createdBy: String? {
        get {
          return snapshot["createdBy"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdBy")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String {
        get {
          return snapshot["updatedAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class DeleteOvertimeAuditEventMutation: GraphQLMutation {
  public static let operationString =
    "mutation DeleteOvertimeAuditEvent($input: DeleteOvertimeAuditEventInput!, $condition: ModelOvertimeAuditEventConditionInput) {\n  deleteOvertimeAuditEvent(input: $input, condition: $condition) {\n    __typename\n    id\n    postingId\n    type\n    details\n    createdBy\n    createdAt\n    updatedAt\n  }\n}"

  public var input: DeleteOvertimeAuditEventInput
  public var condition: ModelOvertimeAuditEventConditionInput?

  public init(input: DeleteOvertimeAuditEventInput, condition: ModelOvertimeAuditEventConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("deleteOvertimeAuditEvent", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(DeleteOvertimeAuditEvent.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(deleteOvertimeAuditEvent: DeleteOvertimeAuditEvent? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "deleteOvertimeAuditEvent": deleteOvertimeAuditEvent.flatMap { $0.snapshot }])
    }

    public var deleteOvertimeAuditEvent: DeleteOvertimeAuditEvent? {
      get {
        return (snapshot["deleteOvertimeAuditEvent"] as? Snapshot).flatMap { DeleteOvertimeAuditEvent(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "deleteOvertimeAuditEvent")
      }
    }

    public struct DeleteOvertimeAuditEvent: GraphQLSelectionSet {
      public static let possibleTypes = ["OvertimeAuditEvent"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("postingId", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("type", type: .nonNull(.scalar(String.self))),
        GraphQLField("details", type: .scalar(String.self)),
        GraphQLField("createdBy", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .nonNull(.scalar(String.self))),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, postingId: GraphQLID, type: String, details: String? = nil, createdBy: String? = nil, createdAt: String? = nil, updatedAt: String) {
        self.init(snapshot: ["__typename": "OvertimeAuditEvent", "id": id, "postingId": postingId, "type": type, "details": details, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var postingId: GraphQLID {
        get {
          return snapshot["postingId"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "postingId")
        }
      }

      public var type: String {
        get {
          return snapshot["type"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "type")
        }
      }

      public var details: String? {
        get {
          return snapshot["details"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "details")
        }
      }

      public var createdBy: String? {
        get {
          return snapshot["createdBy"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdBy")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String {
        get {
          return snapshot["updatedAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class CreateNotificationEndpointMutation: GraphQLMutation {
  public static let operationString =
    "mutation CreateNotificationEndpoint($input: CreateNotificationEndpointInput!, $condition: ModelNotificationEndpointConditionInput) {\n  createNotificationEndpoint(input: $input, condition: $condition) {\n    __typename\n    id\n    orgId\n    userId\n    deviceToken\n    platform\n    deviceName\n    enabled\n    platformEndpointArn\n    lastUsedAt\n    createdAt\n    updatedAt\n  }\n}"

  public var input: CreateNotificationEndpointInput
  public var condition: ModelNotificationEndpointConditionInput?

  public init(input: CreateNotificationEndpointInput, condition: ModelNotificationEndpointConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("createNotificationEndpoint", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(CreateNotificationEndpoint.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(createNotificationEndpoint: CreateNotificationEndpoint? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "createNotificationEndpoint": createNotificationEndpoint.flatMap { $0.snapshot }])
    }

    public var createNotificationEndpoint: CreateNotificationEndpoint? {
      get {
        return (snapshot["createNotificationEndpoint"] as? Snapshot).flatMap { CreateNotificationEndpoint(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "createNotificationEndpoint")
      }
    }

    public struct CreateNotificationEndpoint: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationEndpoint"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("userId", type: .nonNull(.scalar(String.self))),
        GraphQLField("deviceToken", type: .nonNull(.scalar(String.self))),
        GraphQLField("platform", type: .nonNull(.scalar(NotificationPlatform.self))),
        GraphQLField("deviceName", type: .scalar(String.self)),
        GraphQLField("enabled", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("platformEndpointArn", type: .scalar(String.self)),
        GraphQLField("lastUsedAt", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, userId: String, deviceToken: String, platform: NotificationPlatform, deviceName: String? = nil, enabled: Bool, platformEndpointArn: String? = nil, lastUsedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationEndpoint", "id": id, "orgId": orgId, "userId": userId, "deviceToken": deviceToken, "platform": platform, "deviceName": deviceName, "enabled": enabled, "platformEndpointArn": platformEndpointArn, "lastUsedAt": lastUsedAt, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var userId: String {
        get {
          return snapshot["userId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "userId")
        }
      }

      public var deviceToken: String {
        get {
          return snapshot["deviceToken"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "deviceToken")
        }
      }

      public var platform: NotificationPlatform {
        get {
          return snapshot["platform"]! as! NotificationPlatform
        }
        set {
          snapshot.updateValue(newValue, forKey: "platform")
        }
      }

      public var deviceName: String? {
        get {
          return snapshot["deviceName"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "deviceName")
        }
      }

      public var enabled: Bool {
        get {
          return snapshot["enabled"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "enabled")
        }
      }

      public var platformEndpointArn: String? {
        get {
          return snapshot["platformEndpointArn"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "platformEndpointArn")
        }
      }

      public var lastUsedAt: String? {
        get {
          return snapshot["lastUsedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "lastUsedAt")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class UpdateNotificationEndpointMutation: GraphQLMutation {
  public static let operationString =
    "mutation UpdateNotificationEndpoint($input: UpdateNotificationEndpointInput!, $condition: ModelNotificationEndpointConditionInput) {\n  updateNotificationEndpoint(input: $input, condition: $condition) {\n    __typename\n    id\n    orgId\n    userId\n    deviceToken\n    platform\n    deviceName\n    enabled\n    platformEndpointArn\n    lastUsedAt\n    createdAt\n    updatedAt\n  }\n}"

  public var input: UpdateNotificationEndpointInput
  public var condition: ModelNotificationEndpointConditionInput?

  public init(input: UpdateNotificationEndpointInput, condition: ModelNotificationEndpointConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("updateNotificationEndpoint", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(UpdateNotificationEndpoint.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(updateNotificationEndpoint: UpdateNotificationEndpoint? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "updateNotificationEndpoint": updateNotificationEndpoint.flatMap { $0.snapshot }])
    }

    public var updateNotificationEndpoint: UpdateNotificationEndpoint? {
      get {
        return (snapshot["updateNotificationEndpoint"] as? Snapshot).flatMap { UpdateNotificationEndpoint(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "updateNotificationEndpoint")
      }
    }

    public struct UpdateNotificationEndpoint: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationEndpoint"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("userId", type: .nonNull(.scalar(String.self))),
        GraphQLField("deviceToken", type: .nonNull(.scalar(String.self))),
        GraphQLField("platform", type: .nonNull(.scalar(NotificationPlatform.self))),
        GraphQLField("deviceName", type: .scalar(String.self)),
        GraphQLField("enabled", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("platformEndpointArn", type: .scalar(String.self)),
        GraphQLField("lastUsedAt", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, userId: String, deviceToken: String, platform: NotificationPlatform, deviceName: String? = nil, enabled: Bool, platformEndpointArn: String? = nil, lastUsedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationEndpoint", "id": id, "orgId": orgId, "userId": userId, "deviceToken": deviceToken, "platform": platform, "deviceName": deviceName, "enabled": enabled, "platformEndpointArn": platformEndpointArn, "lastUsedAt": lastUsedAt, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var userId: String {
        get {
          return snapshot["userId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "userId")
        }
      }

      public var deviceToken: String {
        get {
          return snapshot["deviceToken"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "deviceToken")
        }
      }

      public var platform: NotificationPlatform {
        get {
          return snapshot["platform"]! as! NotificationPlatform
        }
        set {
          snapshot.updateValue(newValue, forKey: "platform")
        }
      }

      public var deviceName: String? {
        get {
          return snapshot["deviceName"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "deviceName")
        }
      }

      public var enabled: Bool {
        get {
          return snapshot["enabled"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "enabled")
        }
      }

      public var platformEndpointArn: String? {
        get {
          return snapshot["platformEndpointArn"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "platformEndpointArn")
        }
      }

      public var lastUsedAt: String? {
        get {
          return snapshot["lastUsedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "lastUsedAt")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class DeleteNotificationEndpointMutation: GraphQLMutation {
  public static let operationString =
    "mutation DeleteNotificationEndpoint($input: DeleteNotificationEndpointInput!, $condition: ModelNotificationEndpointConditionInput) {\n  deleteNotificationEndpoint(input: $input, condition: $condition) {\n    __typename\n    id\n    orgId\n    userId\n    deviceToken\n    platform\n    deviceName\n    enabled\n    platformEndpointArn\n    lastUsedAt\n    createdAt\n    updatedAt\n  }\n}"

  public var input: DeleteNotificationEndpointInput
  public var condition: ModelNotificationEndpointConditionInput?

  public init(input: DeleteNotificationEndpointInput, condition: ModelNotificationEndpointConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("deleteNotificationEndpoint", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(DeleteNotificationEndpoint.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(deleteNotificationEndpoint: DeleteNotificationEndpoint? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "deleteNotificationEndpoint": deleteNotificationEndpoint.flatMap { $0.snapshot }])
    }

    public var deleteNotificationEndpoint: DeleteNotificationEndpoint? {
      get {
        return (snapshot["deleteNotificationEndpoint"] as? Snapshot).flatMap { DeleteNotificationEndpoint(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "deleteNotificationEndpoint")
      }
    }

    public struct DeleteNotificationEndpoint: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationEndpoint"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("userId", type: .nonNull(.scalar(String.self))),
        GraphQLField("deviceToken", type: .nonNull(.scalar(String.self))),
        GraphQLField("platform", type: .nonNull(.scalar(NotificationPlatform.self))),
        GraphQLField("deviceName", type: .scalar(String.self)),
        GraphQLField("enabled", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("platformEndpointArn", type: .scalar(String.self)),
        GraphQLField("lastUsedAt", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, userId: String, deviceToken: String, platform: NotificationPlatform, deviceName: String? = nil, enabled: Bool, platformEndpointArn: String? = nil, lastUsedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationEndpoint", "id": id, "orgId": orgId, "userId": userId, "deviceToken": deviceToken, "platform": platform, "deviceName": deviceName, "enabled": enabled, "platformEndpointArn": platformEndpointArn, "lastUsedAt": lastUsedAt, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var userId: String {
        get {
          return snapshot["userId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "userId")
        }
      }

      public var deviceToken: String {
        get {
          return snapshot["deviceToken"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "deviceToken")
        }
      }

      public var platform: NotificationPlatform {
        get {
          return snapshot["platform"]! as! NotificationPlatform
        }
        set {
          snapshot.updateValue(newValue, forKey: "platform")
        }
      }

      public var deviceName: String? {
        get {
          return snapshot["deviceName"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "deviceName")
        }
      }

      public var enabled: Bool {
        get {
          return snapshot["enabled"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "enabled")
        }
      }

      public var platformEndpointArn: String? {
        get {
          return snapshot["platformEndpointArn"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "platformEndpointArn")
        }
      }

      public var lastUsedAt: String? {
        get {
          return snapshot["lastUsedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "lastUsedAt")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class CreateNotificationMessageMutation: GraphQLMutation {
  public static let operationString =
    "mutation CreateNotificationMessage($input: CreateNotificationMessageInput!, $condition: ModelNotificationMessageConditionInput) {\n  createNotificationMessage(input: $input, condition: $condition) {\n    __typename\n    id\n    orgId\n    title\n    body\n    category\n    recipients\n    metadata\n    createdBy\n    createdAt\n    updatedAt\n  }\n}"

  public var input: CreateNotificationMessageInput
  public var condition: ModelNotificationMessageConditionInput?

  public init(input: CreateNotificationMessageInput, condition: ModelNotificationMessageConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("createNotificationMessage", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(CreateNotificationMessage.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(createNotificationMessage: CreateNotificationMessage? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "createNotificationMessage": createNotificationMessage.flatMap { $0.snapshot }])
    }

    public var createNotificationMessage: CreateNotificationMessage? {
      get {
        return (snapshot["createNotificationMessage"] as? Snapshot).flatMap { CreateNotificationMessage(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "createNotificationMessage")
      }
    }

    public struct CreateNotificationMessage: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationMessage"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("body", type: .nonNull(.scalar(String.self))),
        GraphQLField("category", type: .nonNull(.scalar(NotificationCategory.self))),
        GraphQLField("recipients", type: .nonNull(.list(.nonNull(.scalar(String.self))))),
        GraphQLField("metadata", type: .scalar(String.self)),
        GraphQLField("createdBy", type: .nonNull(.scalar(String.self))),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, title: String, body: String, category: NotificationCategory, recipients: [String], metadata: String? = nil, createdBy: String, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationMessage", "id": id, "orgId": orgId, "title": title, "body": body, "category": category, "recipients": recipients, "metadata": metadata, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var body: String {
        get {
          return snapshot["body"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "body")
        }
      }

      public var category: NotificationCategory {
        get {
          return snapshot["category"]! as! NotificationCategory
        }
        set {
          snapshot.updateValue(newValue, forKey: "category")
        }
      }

      public var recipients: [String] {
        get {
          return snapshot["recipients"]! as! [String]
        }
        set {
          snapshot.updateValue(newValue, forKey: "recipients")
        }
      }

      public var metadata: String? {
        get {
          return snapshot["metadata"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "metadata")
        }
      }

      public var createdBy: String {
        get {
          return snapshot["createdBy"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdBy")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class UpdateNotificationMessageMutation: GraphQLMutation {
  public static let operationString =
    "mutation UpdateNotificationMessage($input: UpdateNotificationMessageInput!, $condition: ModelNotificationMessageConditionInput) {\n  updateNotificationMessage(input: $input, condition: $condition) {\n    __typename\n    id\n    orgId\n    title\n    body\n    category\n    recipients\n    metadata\n    createdBy\n    createdAt\n    updatedAt\n  }\n}"

  public var input: UpdateNotificationMessageInput
  public var condition: ModelNotificationMessageConditionInput?

  public init(input: UpdateNotificationMessageInput, condition: ModelNotificationMessageConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("updateNotificationMessage", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(UpdateNotificationMessage.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(updateNotificationMessage: UpdateNotificationMessage? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "updateNotificationMessage": updateNotificationMessage.flatMap { $0.snapshot }])
    }

    public var updateNotificationMessage: UpdateNotificationMessage? {
      get {
        return (snapshot["updateNotificationMessage"] as? Snapshot).flatMap { UpdateNotificationMessage(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "updateNotificationMessage")
      }
    }

    public struct UpdateNotificationMessage: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationMessage"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("body", type: .nonNull(.scalar(String.self))),
        GraphQLField("category", type: .nonNull(.scalar(NotificationCategory.self))),
        GraphQLField("recipients", type: .nonNull(.list(.nonNull(.scalar(String.self))))),
        GraphQLField("metadata", type: .scalar(String.self)),
        GraphQLField("createdBy", type: .nonNull(.scalar(String.self))),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, title: String, body: String, category: NotificationCategory, recipients: [String], metadata: String? = nil, createdBy: String, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationMessage", "id": id, "orgId": orgId, "title": title, "body": body, "category": category, "recipients": recipients, "metadata": metadata, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var body: String {
        get {
          return snapshot["body"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "body")
        }
      }

      public var category: NotificationCategory {
        get {
          return snapshot["category"]! as! NotificationCategory
        }
        set {
          snapshot.updateValue(newValue, forKey: "category")
        }
      }

      public var recipients: [String] {
        get {
          return snapshot["recipients"]! as! [String]
        }
        set {
          snapshot.updateValue(newValue, forKey: "recipients")
        }
      }

      public var metadata: String? {
        get {
          return snapshot["metadata"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "metadata")
        }
      }

      public var createdBy: String {
        get {
          return snapshot["createdBy"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdBy")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class DeleteNotificationMessageMutation: GraphQLMutation {
  public static let operationString =
    "mutation DeleteNotificationMessage($input: DeleteNotificationMessageInput!, $condition: ModelNotificationMessageConditionInput) {\n  deleteNotificationMessage(input: $input, condition: $condition) {\n    __typename\n    id\n    orgId\n    title\n    body\n    category\n    recipients\n    metadata\n    createdBy\n    createdAt\n    updatedAt\n  }\n}"

  public var input: DeleteNotificationMessageInput
  public var condition: ModelNotificationMessageConditionInput?

  public init(input: DeleteNotificationMessageInput, condition: ModelNotificationMessageConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("deleteNotificationMessage", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(DeleteNotificationMessage.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(deleteNotificationMessage: DeleteNotificationMessage? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "deleteNotificationMessage": deleteNotificationMessage.flatMap { $0.snapshot }])
    }

    public var deleteNotificationMessage: DeleteNotificationMessage? {
      get {
        return (snapshot["deleteNotificationMessage"] as? Snapshot).flatMap { DeleteNotificationMessage(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "deleteNotificationMessage")
      }
    }

    public struct DeleteNotificationMessage: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationMessage"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("body", type: .nonNull(.scalar(String.self))),
        GraphQLField("category", type: .nonNull(.scalar(NotificationCategory.self))),
        GraphQLField("recipients", type: .nonNull(.list(.nonNull(.scalar(String.self))))),
        GraphQLField("metadata", type: .scalar(String.self)),
        GraphQLField("createdBy", type: .nonNull(.scalar(String.self))),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, title: String, body: String, category: NotificationCategory, recipients: [String], metadata: String? = nil, createdBy: String, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationMessage", "id": id, "orgId": orgId, "title": title, "body": body, "category": category, "recipients": recipients, "metadata": metadata, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var body: String {
        get {
          return snapshot["body"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "body")
        }
      }

      public var category: NotificationCategory {
        get {
          return snapshot["category"]! as! NotificationCategory
        }
        set {
          snapshot.updateValue(newValue, forKey: "category")
        }
      }

      public var recipients: [String] {
        get {
          return snapshot["recipients"]! as! [String]
        }
        set {
          snapshot.updateValue(newValue, forKey: "recipients")
        }
      }

      public var metadata: String? {
        get {
          return snapshot["metadata"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "metadata")
        }
      }

      public var createdBy: String {
        get {
          return snapshot["createdBy"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdBy")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class CreateNotificationPreferenceMutation: GraphQLMutation {
  public static let operationString =
    "mutation CreateNotificationPreference($input: CreateNotificationPreferenceInput!, $condition: ModelNotificationPreferenceConditionInput) {\n  createNotificationPreference(input: $input, condition: $condition) {\n    __typename\n    id\n    userId\n    generalBulletin\n    taskAlert\n    overtime\n    squadMessages\n    other\n    contactPhone\n    contactEmail\n    backupEmail\n    createdAt\n    updatedAt\n  }\n}"

  public var input: CreateNotificationPreferenceInput
  public var condition: ModelNotificationPreferenceConditionInput?

  public init(input: CreateNotificationPreferenceInput, condition: ModelNotificationPreferenceConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("createNotificationPreference", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(CreateNotificationPreference.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(createNotificationPreference: CreateNotificationPreference? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "createNotificationPreference": createNotificationPreference.flatMap { $0.snapshot }])
    }

    public var createNotificationPreference: CreateNotificationPreference? {
      get {
        return (snapshot["createNotificationPreference"] as? Snapshot).flatMap { CreateNotificationPreference(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "createNotificationPreference")
      }
    }

    public struct CreateNotificationPreference: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationPreference"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("userId", type: .nonNull(.scalar(String.self))),
        GraphQLField("generalBulletin", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("taskAlert", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("overtime", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("squadMessages", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("other", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("contactPhone", type: .scalar(String.self)),
        GraphQLField("contactEmail", type: .scalar(String.self)),
        GraphQLField("backupEmail", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, userId: String, generalBulletin: Bool, taskAlert: Bool, overtime: Bool, squadMessages: Bool, other: Bool, contactPhone: String? = nil, contactEmail: String? = nil, backupEmail: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationPreference", "id": id, "userId": userId, "generalBulletin": generalBulletin, "taskAlert": taskAlert, "overtime": overtime, "squadMessages": squadMessages, "other": other, "contactPhone": contactPhone, "contactEmail": contactEmail, "backupEmail": backupEmail, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var userId: String {
        get {
          return snapshot["userId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "userId")
        }
      }

      public var generalBulletin: Bool {
        get {
          return snapshot["generalBulletin"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "generalBulletin")
        }
      }

      public var taskAlert: Bool {
        get {
          return snapshot["taskAlert"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "taskAlert")
        }
      }

      public var overtime: Bool {
        get {
          return snapshot["overtime"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "overtime")
        }
      }

      public var squadMessages: Bool {
        get {
          return snapshot["squadMessages"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "squadMessages")
        }
      }

      public var other: Bool {
        get {
          return snapshot["other"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "other")
        }
      }

      public var contactPhone: String? {
        get {
          return snapshot["contactPhone"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "contactPhone")
        }
      }

      public var contactEmail: String? {
        get {
          return snapshot["contactEmail"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "contactEmail")
        }
      }

      public var backupEmail: String? {
        get {
          return snapshot["backupEmail"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "backupEmail")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class UpdateNotificationPreferenceMutation: GraphQLMutation {
  public static let operationString =
    "mutation UpdateNotificationPreference($input: UpdateNotificationPreferenceInput!, $condition: ModelNotificationPreferenceConditionInput) {\n  updateNotificationPreference(input: $input, condition: $condition) {\n    __typename\n    id\n    userId\n    generalBulletin\n    taskAlert\n    overtime\n    squadMessages\n    other\n    contactPhone\n    contactEmail\n    backupEmail\n    createdAt\n    updatedAt\n  }\n}"

  public var input: UpdateNotificationPreferenceInput
  public var condition: ModelNotificationPreferenceConditionInput?

  public init(input: UpdateNotificationPreferenceInput, condition: ModelNotificationPreferenceConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("updateNotificationPreference", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(UpdateNotificationPreference.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(updateNotificationPreference: UpdateNotificationPreference? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "updateNotificationPreference": updateNotificationPreference.flatMap { $0.snapshot }])
    }

    public var updateNotificationPreference: UpdateNotificationPreference? {
      get {
        return (snapshot["updateNotificationPreference"] as? Snapshot).flatMap { UpdateNotificationPreference(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "updateNotificationPreference")
      }
    }

    public struct UpdateNotificationPreference: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationPreference"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("userId", type: .nonNull(.scalar(String.self))),
        GraphQLField("generalBulletin", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("taskAlert", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("overtime", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("squadMessages", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("other", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("contactPhone", type: .scalar(String.self)),
        GraphQLField("contactEmail", type: .scalar(String.self)),
        GraphQLField("backupEmail", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, userId: String, generalBulletin: Bool, taskAlert: Bool, overtime: Bool, squadMessages: Bool, other: Bool, contactPhone: String? = nil, contactEmail: String? = nil, backupEmail: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationPreference", "id": id, "userId": userId, "generalBulletin": generalBulletin, "taskAlert": taskAlert, "overtime": overtime, "squadMessages": squadMessages, "other": other, "contactPhone": contactPhone, "contactEmail": contactEmail, "backupEmail": backupEmail, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var userId: String {
        get {
          return snapshot["userId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "userId")
        }
      }

      public var generalBulletin: Bool {
        get {
          return snapshot["generalBulletin"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "generalBulletin")
        }
      }

      public var taskAlert: Bool {
        get {
          return snapshot["taskAlert"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "taskAlert")
        }
      }

      public var overtime: Bool {
        get {
          return snapshot["overtime"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "overtime")
        }
      }

      public var squadMessages: Bool {
        get {
          return snapshot["squadMessages"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "squadMessages")
        }
      }

      public var other: Bool {
        get {
          return snapshot["other"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "other")
        }
      }

      public var contactPhone: String? {
        get {
          return snapshot["contactPhone"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "contactPhone")
        }
      }

      public var contactEmail: String? {
        get {
          return snapshot["contactEmail"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "contactEmail")
        }
      }

      public var backupEmail: String? {
        get {
          return snapshot["backupEmail"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "backupEmail")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class DeleteNotificationPreferenceMutation: GraphQLMutation {
  public static let operationString =
    "mutation DeleteNotificationPreference($input: DeleteNotificationPreferenceInput!, $condition: ModelNotificationPreferenceConditionInput) {\n  deleteNotificationPreference(input: $input, condition: $condition) {\n    __typename\n    id\n    userId\n    generalBulletin\n    taskAlert\n    overtime\n    squadMessages\n    other\n    contactPhone\n    contactEmail\n    backupEmail\n    createdAt\n    updatedAt\n  }\n}"

  public var input: DeleteNotificationPreferenceInput
  public var condition: ModelNotificationPreferenceConditionInput?

  public init(input: DeleteNotificationPreferenceInput, condition: ModelNotificationPreferenceConditionInput? = nil) {
    self.input = input
    self.condition = condition
  }

  public var variables: GraphQLMap? {
    return ["input": input, "condition": condition]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Mutation"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("deleteNotificationPreference", arguments: ["input": GraphQLVariable("input"), "condition": GraphQLVariable("condition")], type: .object(DeleteNotificationPreference.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(deleteNotificationPreference: DeleteNotificationPreference? = nil) {
      self.init(snapshot: ["__typename": "Mutation", "deleteNotificationPreference": deleteNotificationPreference.flatMap { $0.snapshot }])
    }

    public var deleteNotificationPreference: DeleteNotificationPreference? {
      get {
        return (snapshot["deleteNotificationPreference"] as? Snapshot).flatMap { DeleteNotificationPreference(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "deleteNotificationPreference")
      }
    }

    public struct DeleteNotificationPreference: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationPreference"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("userId", type: .nonNull(.scalar(String.self))),
        GraphQLField("generalBulletin", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("taskAlert", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("overtime", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("squadMessages", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("other", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("contactPhone", type: .scalar(String.self)),
        GraphQLField("contactEmail", type: .scalar(String.self)),
        GraphQLField("backupEmail", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, userId: String, generalBulletin: Bool, taskAlert: Bool, overtime: Bool, squadMessages: Bool, other: Bool, contactPhone: String? = nil, contactEmail: String? = nil, backupEmail: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationPreference", "id": id, "userId": userId, "generalBulletin": generalBulletin, "taskAlert": taskAlert, "overtime": overtime, "squadMessages": squadMessages, "other": other, "contactPhone": contactPhone, "contactEmail": contactEmail, "backupEmail": backupEmail, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var userId: String {
        get {
          return snapshot["userId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "userId")
        }
      }

      public var generalBulletin: Bool {
        get {
          return snapshot["generalBulletin"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "generalBulletin")
        }
      }

      public var taskAlert: Bool {
        get {
          return snapshot["taskAlert"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "taskAlert")
        }
      }

      public var overtime: Bool {
        get {
          return snapshot["overtime"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "overtime")
        }
      }

      public var squadMessages: Bool {
        get {
          return snapshot["squadMessages"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "squadMessages")
        }
      }

      public var other: Bool {
        get {
          return snapshot["other"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "other")
        }
      }

      public var contactPhone: String? {
        get {
          return snapshot["contactPhone"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "contactPhone")
        }
      }

      public var contactEmail: String? {
        get {
          return snapshot["contactEmail"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "contactEmail")
        }
      }

      public var backupEmail: String? {
        get {
          return snapshot["backupEmail"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "backupEmail")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class GetRosterEntryQuery: GraphQLQuery {
  public static let operationString =
    "query GetRosterEntry($id: ID!) {\n  getRosterEntry(id: $id) {\n    __typename\n    id\n    orgId\n    badgeNumber\n    shift\n    startsAt\n    endsAt\n    notes\n    createdAt\n    updatedAt\n  }\n}"

  public var id: GraphQLID

  public init(id: GraphQLID) {
    self.id = id
  }

  public var variables: GraphQLMap? {
    return ["id": id]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("getRosterEntry", arguments: ["id": GraphQLVariable("id")], type: .object(GetRosterEntry.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(getRosterEntry: GetRosterEntry? = nil) {
      self.init(snapshot: ["__typename": "Query", "getRosterEntry": getRosterEntry.flatMap { $0.snapshot }])
    }

    public var getRosterEntry: GetRosterEntry? {
      get {
        return (snapshot["getRosterEntry"] as? Snapshot).flatMap { GetRosterEntry(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "getRosterEntry")
      }
    }

    public struct GetRosterEntry: GraphQLSelectionSet {
      public static let possibleTypes = ["RosterEntry"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("badgeNumber", type: .nonNull(.scalar(String.self))),
        GraphQLField("shift", type: .scalar(String.self)),
        GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("notes", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, badgeNumber: String, shift: String? = nil, startsAt: String, endsAt: String, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "RosterEntry", "id": id, "orgId": orgId, "badgeNumber": badgeNumber, "shift": shift, "startsAt": startsAt, "endsAt": endsAt, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var badgeNumber: String {
        get {
          return snapshot["badgeNumber"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "badgeNumber")
        }
      }

      public var shift: String? {
        get {
          return snapshot["shift"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "shift")
        }
      }

      public var startsAt: String {
        get {
          return snapshot["startsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "startsAt")
        }
      }

      public var endsAt: String {
        get {
          return snapshot["endsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "endsAt")
        }
      }

      public var notes: String? {
        get {
          return snapshot["notes"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "notes")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class ListRosterEntriesQuery: GraphQLQuery {
  public static let operationString =
    "query ListRosterEntries($filter: ModelRosterEntryFilterInput, $limit: Int, $nextToken: String) {\n  listRosterEntries(filter: $filter, limit: $limit, nextToken: $nextToken) {\n    __typename\n    items {\n      __typename\n      id\n      orgId\n      badgeNumber\n      shift\n      startsAt\n      endsAt\n      notes\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var filter: ModelRosterEntryFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(filter: ModelRosterEntryFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("listRosterEntries", arguments: ["filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(ListRosterEntry.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(listRosterEntries: ListRosterEntry? = nil) {
      self.init(snapshot: ["__typename": "Query", "listRosterEntries": listRosterEntries.flatMap { $0.snapshot }])
    }

    public var listRosterEntries: ListRosterEntry? {
      get {
        return (snapshot["listRosterEntries"] as? Snapshot).flatMap { ListRosterEntry(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "listRosterEntries")
      }
    }

    public struct ListRosterEntry: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelRosterEntryConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelRosterEntryConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["RosterEntry"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
          GraphQLField("badgeNumber", type: .nonNull(.scalar(String.self))),
          GraphQLField("shift", type: .scalar(String.self)),
          GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
          GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
          GraphQLField("notes", type: .scalar(String.self)),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, orgId: String, badgeNumber: String, shift: String? = nil, startsAt: String, endsAt: String, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
          self.init(snapshot: ["__typename": "RosterEntry", "id": id, "orgId": orgId, "badgeNumber": badgeNumber, "shift": shift, "startsAt": startsAt, "endsAt": endsAt, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var orgId: String {
          get {
            return snapshot["orgId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "orgId")
          }
        }

        public var badgeNumber: String {
          get {
            return snapshot["badgeNumber"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "badgeNumber")
          }
        }

        public var shift: String? {
          get {
            return snapshot["shift"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "shift")
          }
        }

        public var startsAt: String {
          get {
            return snapshot["startsAt"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "startsAt")
          }
        }

        public var endsAt: String {
          get {
            return snapshot["endsAt"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "endsAt")
          }
        }

        public var notes: String? {
          get {
            return snapshot["notes"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "notes")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String? {
          get {
            return snapshot["updatedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class RosterEntriesByOrgQuery: GraphQLQuery {
  public static let operationString =
    "query RosterEntriesByOrg($orgId: String!, $startsAt: ModelStringKeyConditionInput, $sortDirection: ModelSortDirection, $filter: ModelRosterEntryFilterInput, $limit: Int, $nextToken: String) {\n  rosterEntriesByOrg(\n    orgId: $orgId\n    startsAt: $startsAt\n    sortDirection: $sortDirection\n    filter: $filter\n    limit: $limit\n    nextToken: $nextToken\n  ) {\n    __typename\n    items {\n      __typename\n      id\n      orgId\n      badgeNumber\n      shift\n      startsAt\n      endsAt\n      notes\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var orgId: String
  public var startsAt: ModelStringKeyConditionInput?
  public var sortDirection: ModelSortDirection?
  public var filter: ModelRosterEntryFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(orgId: String, startsAt: ModelStringKeyConditionInput? = nil, sortDirection: ModelSortDirection? = nil, filter: ModelRosterEntryFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.orgId = orgId
    self.startsAt = startsAt
    self.sortDirection = sortDirection
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["orgId": orgId, "startsAt": startsAt, "sortDirection": sortDirection, "filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("rosterEntriesByOrg", arguments: ["orgId": GraphQLVariable("orgId"), "startsAt": GraphQLVariable("startsAt"), "sortDirection": GraphQLVariable("sortDirection"), "filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(RosterEntriesByOrg.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(rosterEntriesByOrg: RosterEntriesByOrg? = nil) {
      self.init(snapshot: ["__typename": "Query", "rosterEntriesByOrg": rosterEntriesByOrg.flatMap { $0.snapshot }])
    }

    public var rosterEntriesByOrg: RosterEntriesByOrg? {
      get {
        return (snapshot["rosterEntriesByOrg"] as? Snapshot).flatMap { RosterEntriesByOrg(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "rosterEntriesByOrg")
      }
    }

    public struct RosterEntriesByOrg: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelRosterEntryConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelRosterEntryConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["RosterEntry"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
          GraphQLField("badgeNumber", type: .nonNull(.scalar(String.self))),
          GraphQLField("shift", type: .scalar(String.self)),
          GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
          GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
          GraphQLField("notes", type: .scalar(String.self)),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, orgId: String, badgeNumber: String, shift: String? = nil, startsAt: String, endsAt: String, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
          self.init(snapshot: ["__typename": "RosterEntry", "id": id, "orgId": orgId, "badgeNumber": badgeNumber, "shift": shift, "startsAt": startsAt, "endsAt": endsAt, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var orgId: String {
          get {
            return snapshot["orgId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "orgId")
          }
        }

        public var badgeNumber: String {
          get {
            return snapshot["badgeNumber"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "badgeNumber")
          }
        }

        public var shift: String? {
          get {
            return snapshot["shift"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "shift")
          }
        }

        public var startsAt: String {
          get {
            return snapshot["startsAt"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "startsAt")
          }
        }

        public var endsAt: String {
          get {
            return snapshot["endsAt"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "endsAt")
          }
        }

        public var notes: String? {
          get {
            return snapshot["notes"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "notes")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String? {
          get {
            return snapshot["updatedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class GetVehicleQuery: GraphQLQuery {
  public static let operationString =
    "query GetVehicle($id: ID!) {\n  getVehicle(id: $id) {\n    __typename\n    id\n    orgId\n    callsign\n    make\n    model\n    plate\n    inService\n    createdAt\n    updatedAt\n  }\n}"

  public var id: GraphQLID

  public init(id: GraphQLID) {
    self.id = id
  }

  public var variables: GraphQLMap? {
    return ["id": id]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("getVehicle", arguments: ["id": GraphQLVariable("id")], type: .object(GetVehicle.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(getVehicle: GetVehicle? = nil) {
      self.init(snapshot: ["__typename": "Query", "getVehicle": getVehicle.flatMap { $0.snapshot }])
    }

    public var getVehicle: GetVehicle? {
      get {
        return (snapshot["getVehicle"] as? Snapshot).flatMap { GetVehicle(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "getVehicle")
      }
    }

    public struct GetVehicle: GraphQLSelectionSet {
      public static let possibleTypes = ["Vehicle"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("callsign", type: .nonNull(.scalar(String.self))),
        GraphQLField("make", type: .scalar(String.self)),
        GraphQLField("model", type: .scalar(String.self)),
        GraphQLField("plate", type: .scalar(String.self)),
        GraphQLField("inService", type: .scalar(Bool.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, callsign: String, make: String? = nil, model: String? = nil, plate: String? = nil, inService: Bool? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "Vehicle", "id": id, "orgId": orgId, "callsign": callsign, "make": make, "model": model, "plate": plate, "inService": inService, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var callsign: String {
        get {
          return snapshot["callsign"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "callsign")
        }
      }

      public var make: String? {
        get {
          return snapshot["make"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "make")
        }
      }

      public var model: String? {
        get {
          return snapshot["model"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "model")
        }
      }

      public var plate: String? {
        get {
          return snapshot["plate"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "plate")
        }
      }

      public var inService: Bool? {
        get {
          return snapshot["inService"] as? Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "inService")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class ListVehiclesQuery: GraphQLQuery {
  public static let operationString =
    "query ListVehicles($filter: ModelVehicleFilterInput, $limit: Int, $nextToken: String) {\n  listVehicles(filter: $filter, limit: $limit, nextToken: $nextToken) {\n    __typename\n    items {\n      __typename\n      id\n      orgId\n      callsign\n      make\n      model\n      plate\n      inService\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var filter: ModelVehicleFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(filter: ModelVehicleFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("listVehicles", arguments: ["filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(ListVehicle.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(listVehicles: ListVehicle? = nil) {
      self.init(snapshot: ["__typename": "Query", "listVehicles": listVehicles.flatMap { $0.snapshot }])
    }

    public var listVehicles: ListVehicle? {
      get {
        return (snapshot["listVehicles"] as? Snapshot).flatMap { ListVehicle(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "listVehicles")
      }
    }

    public struct ListVehicle: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelVehicleConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelVehicleConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["Vehicle"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
          GraphQLField("callsign", type: .nonNull(.scalar(String.self))),
          GraphQLField("make", type: .scalar(String.self)),
          GraphQLField("model", type: .scalar(String.self)),
          GraphQLField("plate", type: .scalar(String.self)),
          GraphQLField("inService", type: .scalar(Bool.self)),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, orgId: String, callsign: String, make: String? = nil, model: String? = nil, plate: String? = nil, inService: Bool? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
          self.init(snapshot: ["__typename": "Vehicle", "id": id, "orgId": orgId, "callsign": callsign, "make": make, "model": model, "plate": plate, "inService": inService, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var orgId: String {
          get {
            return snapshot["orgId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "orgId")
          }
        }

        public var callsign: String {
          get {
            return snapshot["callsign"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "callsign")
          }
        }

        public var make: String? {
          get {
            return snapshot["make"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "make")
          }
        }

        public var model: String? {
          get {
            return snapshot["model"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "model")
          }
        }

        public var plate: String? {
          get {
            return snapshot["plate"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "plate")
          }
        }

        public var inService: Bool? {
          get {
            return snapshot["inService"] as? Bool
          }
          set {
            snapshot.updateValue(newValue, forKey: "inService")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String? {
          get {
            return snapshot["updatedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class VehiclesByOrgQuery: GraphQLQuery {
  public static let operationString =
    "query VehiclesByOrg($orgId: String!, $callsign: ModelStringKeyConditionInput, $sortDirection: ModelSortDirection, $filter: ModelVehicleFilterInput, $limit: Int, $nextToken: String) {\n  vehiclesByOrg(\n    orgId: $orgId\n    callsign: $callsign\n    sortDirection: $sortDirection\n    filter: $filter\n    limit: $limit\n    nextToken: $nextToken\n  ) {\n    __typename\n    items {\n      __typename\n      id\n      orgId\n      callsign\n      make\n      model\n      plate\n      inService\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var orgId: String
  public var callsign: ModelStringKeyConditionInput?
  public var sortDirection: ModelSortDirection?
  public var filter: ModelVehicleFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(orgId: String, callsign: ModelStringKeyConditionInput? = nil, sortDirection: ModelSortDirection? = nil, filter: ModelVehicleFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.orgId = orgId
    self.callsign = callsign
    self.sortDirection = sortDirection
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["orgId": orgId, "callsign": callsign, "sortDirection": sortDirection, "filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("vehiclesByOrg", arguments: ["orgId": GraphQLVariable("orgId"), "callsign": GraphQLVariable("callsign"), "sortDirection": GraphQLVariable("sortDirection"), "filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(VehiclesByOrg.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(vehiclesByOrg: VehiclesByOrg? = nil) {
      self.init(snapshot: ["__typename": "Query", "vehiclesByOrg": vehiclesByOrg.flatMap { $0.snapshot }])
    }

    public var vehiclesByOrg: VehiclesByOrg? {
      get {
        return (snapshot["vehiclesByOrg"] as? Snapshot).flatMap { VehiclesByOrg(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "vehiclesByOrg")
      }
    }

    public struct VehiclesByOrg: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelVehicleConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelVehicleConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["Vehicle"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
          GraphQLField("callsign", type: .nonNull(.scalar(String.self))),
          GraphQLField("make", type: .scalar(String.self)),
          GraphQLField("model", type: .scalar(String.self)),
          GraphQLField("plate", type: .scalar(String.self)),
          GraphQLField("inService", type: .scalar(Bool.self)),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, orgId: String, callsign: String, make: String? = nil, model: String? = nil, plate: String? = nil, inService: Bool? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
          self.init(snapshot: ["__typename": "Vehicle", "id": id, "orgId": orgId, "callsign": callsign, "make": make, "model": model, "plate": plate, "inService": inService, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var orgId: String {
          get {
            return snapshot["orgId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "orgId")
          }
        }

        public var callsign: String {
          get {
            return snapshot["callsign"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "callsign")
          }
        }

        public var make: String? {
          get {
            return snapshot["make"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "make")
          }
        }

        public var model: String? {
          get {
            return snapshot["model"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "model")
          }
        }

        public var plate: String? {
          get {
            return snapshot["plate"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "plate")
          }
        }

        public var inService: Bool? {
          get {
            return snapshot["inService"] as? Bool
          }
          set {
            snapshot.updateValue(newValue, forKey: "inService")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String? {
          get {
            return snapshot["updatedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class GetCalendarEventQuery: GraphQLQuery {
  public static let operationString =
    "query GetCalendarEvent($id: ID!) {\n  getCalendarEvent(id: $id) {\n    __typename\n    id\n    orgId\n    ownerId\n    title\n    category\n    color\n    notes\n    startsAt\n    endsAt\n    reminderMinutesBefore\n    createdAt\n    updatedAt\n  }\n}"

  public var id: GraphQLID

  public init(id: GraphQLID) {
    self.id = id
  }

  public var variables: GraphQLMap? {
    return ["id": id]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("getCalendarEvent", arguments: ["id": GraphQLVariable("id")], type: .object(GetCalendarEvent.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(getCalendarEvent: GetCalendarEvent? = nil) {
      self.init(snapshot: ["__typename": "Query", "getCalendarEvent": getCalendarEvent.flatMap { $0.snapshot }])
    }

    public var getCalendarEvent: GetCalendarEvent? {
      get {
        return (snapshot["getCalendarEvent"] as? Snapshot).flatMap { GetCalendarEvent(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "getCalendarEvent")
      }
    }

    public struct GetCalendarEvent: GraphQLSelectionSet {
      public static let possibleTypes = ["CalendarEvent"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("ownerId", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("category", type: .nonNull(.scalar(String.self))),
        GraphQLField("color", type: .nonNull(.scalar(String.self))),
        GraphQLField("notes", type: .scalar(String.self)),
        GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("reminderMinutesBefore", type: .scalar(Int.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, ownerId: String, title: String, category: String, color: String, notes: String? = nil, startsAt: String, endsAt: String, reminderMinutesBefore: Int? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "CalendarEvent", "id": id, "orgId": orgId, "ownerId": ownerId, "title": title, "category": category, "color": color, "notes": notes, "startsAt": startsAt, "endsAt": endsAt, "reminderMinutesBefore": reminderMinutesBefore, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var ownerId: String {
        get {
          return snapshot["ownerId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "ownerId")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var category: String {
        get {
          return snapshot["category"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "category")
        }
      }

      public var color: String {
        get {
          return snapshot["color"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "color")
        }
      }

      public var notes: String? {
        get {
          return snapshot["notes"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "notes")
        }
      }

      public var startsAt: String {
        get {
          return snapshot["startsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "startsAt")
        }
      }

      public var endsAt: String {
        get {
          return snapshot["endsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "endsAt")
        }
      }

      public var reminderMinutesBefore: Int? {
        get {
          return snapshot["reminderMinutesBefore"] as? Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "reminderMinutesBefore")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class ListCalendarEventsQuery: GraphQLQuery {
  public static let operationString =
    "query ListCalendarEvents($filter: ModelCalendarEventFilterInput, $limit: Int, $nextToken: String) {\n  listCalendarEvents(filter: $filter, limit: $limit, nextToken: $nextToken) {\n    __typename\n    items {\n      __typename\n      id\n      orgId\n      ownerId\n      title\n      category\n      color\n      notes\n      startsAt\n      endsAt\n      reminderMinutesBefore\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var filter: ModelCalendarEventFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(filter: ModelCalendarEventFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("listCalendarEvents", arguments: ["filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(ListCalendarEvent.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(listCalendarEvents: ListCalendarEvent? = nil) {
      self.init(snapshot: ["__typename": "Query", "listCalendarEvents": listCalendarEvents.flatMap { $0.snapshot }])
    }

    public var listCalendarEvents: ListCalendarEvent? {
      get {
        return (snapshot["listCalendarEvents"] as? Snapshot).flatMap { ListCalendarEvent(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "listCalendarEvents")
      }
    }

    public struct ListCalendarEvent: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelCalendarEventConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelCalendarEventConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["CalendarEvent"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
          GraphQLField("ownerId", type: .nonNull(.scalar(String.self))),
          GraphQLField("title", type: .nonNull(.scalar(String.self))),
          GraphQLField("category", type: .nonNull(.scalar(String.self))),
          GraphQLField("color", type: .nonNull(.scalar(String.self))),
          GraphQLField("notes", type: .scalar(String.self)),
          GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
          GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
          GraphQLField("reminderMinutesBefore", type: .scalar(Int.self)),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, orgId: String, ownerId: String, title: String, category: String, color: String, notes: String? = nil, startsAt: String, endsAt: String, reminderMinutesBefore: Int? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
          self.init(snapshot: ["__typename": "CalendarEvent", "id": id, "orgId": orgId, "ownerId": ownerId, "title": title, "category": category, "color": color, "notes": notes, "startsAt": startsAt, "endsAt": endsAt, "reminderMinutesBefore": reminderMinutesBefore, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var orgId: String {
          get {
            return snapshot["orgId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "orgId")
          }
        }

        public var ownerId: String {
          get {
            return snapshot["ownerId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "ownerId")
          }
        }

        public var title: String {
          get {
            return snapshot["title"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "title")
          }
        }

        public var category: String {
          get {
            return snapshot["category"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "category")
          }
        }

        public var color: String {
          get {
            return snapshot["color"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "color")
          }
        }

        public var notes: String? {
          get {
            return snapshot["notes"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "notes")
          }
        }

        public var startsAt: String {
          get {
            return snapshot["startsAt"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "startsAt")
          }
        }

        public var endsAt: String {
          get {
            return snapshot["endsAt"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "endsAt")
          }
        }

        public var reminderMinutesBefore: Int? {
          get {
            return snapshot["reminderMinutesBefore"] as? Int
          }
          set {
            snapshot.updateValue(newValue, forKey: "reminderMinutesBefore")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String? {
          get {
            return snapshot["updatedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class CalendarEventsByOrgQuery: GraphQLQuery {
  public static let operationString =
    "query CalendarEventsByOrg($orgId: String!, $startsAt: ModelStringKeyConditionInput, $sortDirection: ModelSortDirection, $filter: ModelCalendarEventFilterInput, $limit: Int, $nextToken: String) {\n  calendarEventsByOrg(\n    orgId: $orgId\n    startsAt: $startsAt\n    sortDirection: $sortDirection\n    filter: $filter\n    limit: $limit\n    nextToken: $nextToken\n  ) {\n    __typename\n    items {\n      __typename\n      id\n      orgId\n      ownerId\n      title\n      category\n      color\n      notes\n      startsAt\n      endsAt\n      reminderMinutesBefore\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var orgId: String
  public var startsAt: ModelStringKeyConditionInput?
  public var sortDirection: ModelSortDirection?
  public var filter: ModelCalendarEventFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(orgId: String, startsAt: ModelStringKeyConditionInput? = nil, sortDirection: ModelSortDirection? = nil, filter: ModelCalendarEventFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.orgId = orgId
    self.startsAt = startsAt
    self.sortDirection = sortDirection
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["orgId": orgId, "startsAt": startsAt, "sortDirection": sortDirection, "filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("calendarEventsByOrg", arguments: ["orgId": GraphQLVariable("orgId"), "startsAt": GraphQLVariable("startsAt"), "sortDirection": GraphQLVariable("sortDirection"), "filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(CalendarEventsByOrg.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(calendarEventsByOrg: CalendarEventsByOrg? = nil) {
      self.init(snapshot: ["__typename": "Query", "calendarEventsByOrg": calendarEventsByOrg.flatMap { $0.snapshot }])
    }

    public var calendarEventsByOrg: CalendarEventsByOrg? {
      get {
        return (snapshot["calendarEventsByOrg"] as? Snapshot).flatMap { CalendarEventsByOrg(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "calendarEventsByOrg")
      }
    }

    public struct CalendarEventsByOrg: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelCalendarEventConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelCalendarEventConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["CalendarEvent"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
          GraphQLField("ownerId", type: .nonNull(.scalar(String.self))),
          GraphQLField("title", type: .nonNull(.scalar(String.self))),
          GraphQLField("category", type: .nonNull(.scalar(String.self))),
          GraphQLField("color", type: .nonNull(.scalar(String.self))),
          GraphQLField("notes", type: .scalar(String.self)),
          GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
          GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
          GraphQLField("reminderMinutesBefore", type: .scalar(Int.self)),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, orgId: String, ownerId: String, title: String, category: String, color: String, notes: String? = nil, startsAt: String, endsAt: String, reminderMinutesBefore: Int? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
          self.init(snapshot: ["__typename": "CalendarEvent", "id": id, "orgId": orgId, "ownerId": ownerId, "title": title, "category": category, "color": color, "notes": notes, "startsAt": startsAt, "endsAt": endsAt, "reminderMinutesBefore": reminderMinutesBefore, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var orgId: String {
          get {
            return snapshot["orgId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "orgId")
          }
        }

        public var ownerId: String {
          get {
            return snapshot["ownerId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "ownerId")
          }
        }

        public var title: String {
          get {
            return snapshot["title"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "title")
          }
        }

        public var category: String {
          get {
            return snapshot["category"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "category")
          }
        }

        public var color: String {
          get {
            return snapshot["color"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "color")
          }
        }

        public var notes: String? {
          get {
            return snapshot["notes"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "notes")
          }
        }

        public var startsAt: String {
          get {
            return snapshot["startsAt"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "startsAt")
          }
        }

        public var endsAt: String {
          get {
            return snapshot["endsAt"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "endsAt")
          }
        }

        public var reminderMinutesBefore: Int? {
          get {
            return snapshot["reminderMinutesBefore"] as? Int
          }
          set {
            snapshot.updateValue(newValue, forKey: "reminderMinutesBefore")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String? {
          get {
            return snapshot["updatedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class CalendarEventsByOwnerQuery: GraphQLQuery {
  public static let operationString =
    "query CalendarEventsByOwner($ownerId: String!, $startsAt: ModelStringKeyConditionInput, $sortDirection: ModelSortDirection, $filter: ModelCalendarEventFilterInput, $limit: Int, $nextToken: String) {\n  calendarEventsByOwner(\n    ownerId: $ownerId\n    startsAt: $startsAt\n    sortDirection: $sortDirection\n    filter: $filter\n    limit: $limit\n    nextToken: $nextToken\n  ) {\n    __typename\n    items {\n      __typename\n      id\n      orgId\n      ownerId\n      title\n      category\n      color\n      notes\n      startsAt\n      endsAt\n      reminderMinutesBefore\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var ownerId: String
  public var startsAt: ModelStringKeyConditionInput?
  public var sortDirection: ModelSortDirection?
  public var filter: ModelCalendarEventFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(ownerId: String, startsAt: ModelStringKeyConditionInput? = nil, sortDirection: ModelSortDirection? = nil, filter: ModelCalendarEventFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.ownerId = ownerId
    self.startsAt = startsAt
    self.sortDirection = sortDirection
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["ownerId": ownerId, "startsAt": startsAt, "sortDirection": sortDirection, "filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("calendarEventsByOwner", arguments: ["ownerId": GraphQLVariable("ownerId"), "startsAt": GraphQLVariable("startsAt"), "sortDirection": GraphQLVariable("sortDirection"), "filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(CalendarEventsByOwner.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(calendarEventsByOwner: CalendarEventsByOwner? = nil) {
      self.init(snapshot: ["__typename": "Query", "calendarEventsByOwner": calendarEventsByOwner.flatMap { $0.snapshot }])
    }

    public var calendarEventsByOwner: CalendarEventsByOwner? {
      get {
        return (snapshot["calendarEventsByOwner"] as? Snapshot).flatMap { CalendarEventsByOwner(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "calendarEventsByOwner")
      }
    }

    public struct CalendarEventsByOwner: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelCalendarEventConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelCalendarEventConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["CalendarEvent"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
          GraphQLField("ownerId", type: .nonNull(.scalar(String.self))),
          GraphQLField("title", type: .nonNull(.scalar(String.self))),
          GraphQLField("category", type: .nonNull(.scalar(String.self))),
          GraphQLField("color", type: .nonNull(.scalar(String.self))),
          GraphQLField("notes", type: .scalar(String.self)),
          GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
          GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
          GraphQLField("reminderMinutesBefore", type: .scalar(Int.self)),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, orgId: String, ownerId: String, title: String, category: String, color: String, notes: String? = nil, startsAt: String, endsAt: String, reminderMinutesBefore: Int? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
          self.init(snapshot: ["__typename": "CalendarEvent", "id": id, "orgId": orgId, "ownerId": ownerId, "title": title, "category": category, "color": color, "notes": notes, "startsAt": startsAt, "endsAt": endsAt, "reminderMinutesBefore": reminderMinutesBefore, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var orgId: String {
          get {
            return snapshot["orgId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "orgId")
          }
        }

        public var ownerId: String {
          get {
            return snapshot["ownerId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "ownerId")
          }
        }

        public var title: String {
          get {
            return snapshot["title"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "title")
          }
        }

        public var category: String {
          get {
            return snapshot["category"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "category")
          }
        }

        public var color: String {
          get {
            return snapshot["color"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "color")
          }
        }

        public var notes: String? {
          get {
            return snapshot["notes"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "notes")
          }
        }

        public var startsAt: String {
          get {
            return snapshot["startsAt"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "startsAt")
          }
        }

        public var endsAt: String {
          get {
            return snapshot["endsAt"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "endsAt")
          }
        }

        public var reminderMinutesBefore: Int? {
          get {
            return snapshot["reminderMinutesBefore"] as? Int
          }
          set {
            snapshot.updateValue(newValue, forKey: "reminderMinutesBefore")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String? {
          get {
            return snapshot["updatedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class GetOfficerAssignmentQuery: GraphQLQuery {
  public static let operationString =
    "query GetOfficerAssignment($id: ID!) {\n  getOfficerAssignment(id: $id) {\n    __typename\n    id\n    orgId\n    badgeNumber\n    title\n    detail\n    location\n    notes\n    createdAt\n    updatedAt\n  }\n}"

  public var id: GraphQLID

  public init(id: GraphQLID) {
    self.id = id
  }

  public var variables: GraphQLMap? {
    return ["id": id]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("getOfficerAssignment", arguments: ["id": GraphQLVariable("id")], type: .object(GetOfficerAssignment.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(getOfficerAssignment: GetOfficerAssignment? = nil) {
      self.init(snapshot: ["__typename": "Query", "getOfficerAssignment": getOfficerAssignment.flatMap { $0.snapshot }])
    }

    public var getOfficerAssignment: GetOfficerAssignment? {
      get {
        return (snapshot["getOfficerAssignment"] as? Snapshot).flatMap { GetOfficerAssignment(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "getOfficerAssignment")
      }
    }

    public struct GetOfficerAssignment: GraphQLSelectionSet {
      public static let possibleTypes = ["OfficerAssignment"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("badgeNumber", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("detail", type: .scalar(String.self)),
        GraphQLField("location", type: .scalar(String.self)),
        GraphQLField("notes", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, badgeNumber: String, title: String, detail: String? = nil, location: String? = nil, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "OfficerAssignment", "id": id, "orgId": orgId, "badgeNumber": badgeNumber, "title": title, "detail": detail, "location": location, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var badgeNumber: String {
        get {
          return snapshot["badgeNumber"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "badgeNumber")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var detail: String? {
        get {
          return snapshot["detail"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "detail")
        }
      }

      public var location: String? {
        get {
          return snapshot["location"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "location")
        }
      }

      public var notes: String? {
        get {
          return snapshot["notes"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "notes")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class ListOfficerAssignmentsQuery: GraphQLQuery {
  public static let operationString =
    "query ListOfficerAssignments($filter: ModelOfficerAssignmentFilterInput, $limit: Int, $nextToken: String) {\n  listOfficerAssignments(filter: $filter, limit: $limit, nextToken: $nextToken) {\n    __typename\n    items {\n      __typename\n      id\n      orgId\n      badgeNumber\n      title\n      detail\n      location\n      notes\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var filter: ModelOfficerAssignmentFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(filter: ModelOfficerAssignmentFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("listOfficerAssignments", arguments: ["filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(ListOfficerAssignment.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(listOfficerAssignments: ListOfficerAssignment? = nil) {
      self.init(snapshot: ["__typename": "Query", "listOfficerAssignments": listOfficerAssignments.flatMap { $0.snapshot }])
    }

    public var listOfficerAssignments: ListOfficerAssignment? {
      get {
        return (snapshot["listOfficerAssignments"] as? Snapshot).flatMap { ListOfficerAssignment(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "listOfficerAssignments")
      }
    }

    public struct ListOfficerAssignment: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelOfficerAssignmentConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelOfficerAssignmentConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["OfficerAssignment"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
          GraphQLField("badgeNumber", type: .nonNull(.scalar(String.self))),
          GraphQLField("title", type: .nonNull(.scalar(String.self))),
          GraphQLField("detail", type: .scalar(String.self)),
          GraphQLField("location", type: .scalar(String.self)),
          GraphQLField("notes", type: .scalar(String.self)),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, orgId: String, badgeNumber: String, title: String, detail: String? = nil, location: String? = nil, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
          self.init(snapshot: ["__typename": "OfficerAssignment", "id": id, "orgId": orgId, "badgeNumber": badgeNumber, "title": title, "detail": detail, "location": location, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var orgId: String {
          get {
            return snapshot["orgId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "orgId")
          }
        }

        public var badgeNumber: String {
          get {
            return snapshot["badgeNumber"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "badgeNumber")
          }
        }

        public var title: String {
          get {
            return snapshot["title"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "title")
          }
        }

        public var detail: String? {
          get {
            return snapshot["detail"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "detail")
          }
        }

        public var location: String? {
          get {
            return snapshot["location"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "location")
          }
        }

        public var notes: String? {
          get {
            return snapshot["notes"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "notes")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String? {
          get {
            return snapshot["updatedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class AssignmentsByOrgQuery: GraphQLQuery {
  public static let operationString =
    "query AssignmentsByOrg($orgId: String!, $updatedAt: ModelStringKeyConditionInput, $sortDirection: ModelSortDirection, $filter: ModelOfficerAssignmentFilterInput, $limit: Int, $nextToken: String) {\n  assignmentsByOrg(\n    orgId: $orgId\n    updatedAt: $updatedAt\n    sortDirection: $sortDirection\n    filter: $filter\n    limit: $limit\n    nextToken: $nextToken\n  ) {\n    __typename\n    items {\n      __typename\n      id\n      orgId\n      badgeNumber\n      title\n      detail\n      location\n      notes\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var orgId: String
  public var updatedAt: ModelStringKeyConditionInput?
  public var sortDirection: ModelSortDirection?
  public var filter: ModelOfficerAssignmentFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(orgId: String, updatedAt: ModelStringKeyConditionInput? = nil, sortDirection: ModelSortDirection? = nil, filter: ModelOfficerAssignmentFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.orgId = orgId
    self.updatedAt = updatedAt
    self.sortDirection = sortDirection
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["orgId": orgId, "updatedAt": updatedAt, "sortDirection": sortDirection, "filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("assignmentsByOrg", arguments: ["orgId": GraphQLVariable("orgId"), "updatedAt": GraphQLVariable("updatedAt"), "sortDirection": GraphQLVariable("sortDirection"), "filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(AssignmentsByOrg.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(assignmentsByOrg: AssignmentsByOrg? = nil) {
      self.init(snapshot: ["__typename": "Query", "assignmentsByOrg": assignmentsByOrg.flatMap { $0.snapshot }])
    }

    public var assignmentsByOrg: AssignmentsByOrg? {
      get {
        return (snapshot["assignmentsByOrg"] as? Snapshot).flatMap { AssignmentsByOrg(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "assignmentsByOrg")
      }
    }

    public struct AssignmentsByOrg: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelOfficerAssignmentConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelOfficerAssignmentConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["OfficerAssignment"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
          GraphQLField("badgeNumber", type: .nonNull(.scalar(String.self))),
          GraphQLField("title", type: .nonNull(.scalar(String.self))),
          GraphQLField("detail", type: .scalar(String.self)),
          GraphQLField("location", type: .scalar(String.self)),
          GraphQLField("notes", type: .scalar(String.self)),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, orgId: String, badgeNumber: String, title: String, detail: String? = nil, location: String? = nil, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
          self.init(snapshot: ["__typename": "OfficerAssignment", "id": id, "orgId": orgId, "badgeNumber": badgeNumber, "title": title, "detail": detail, "location": location, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var orgId: String {
          get {
            return snapshot["orgId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "orgId")
          }
        }

        public var badgeNumber: String {
          get {
            return snapshot["badgeNumber"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "badgeNumber")
          }
        }

        public var title: String {
          get {
            return snapshot["title"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "title")
          }
        }

        public var detail: String? {
          get {
            return snapshot["detail"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "detail")
          }
        }

        public var location: String? {
          get {
            return snapshot["location"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "location")
          }
        }

        public var notes: String? {
          get {
            return snapshot["notes"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "notes")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String? {
          get {
            return snapshot["updatedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class AssignmentsByOfficerQuery: GraphQLQuery {
  public static let operationString =
    "query AssignmentsByOfficer($badgeNumber: String!, $updatedAt: ModelStringKeyConditionInput, $sortDirection: ModelSortDirection, $filter: ModelOfficerAssignmentFilterInput, $limit: Int, $nextToken: String) {\n  assignmentsByOfficer(\n    badgeNumber: $badgeNumber\n    updatedAt: $updatedAt\n    sortDirection: $sortDirection\n    filter: $filter\n    limit: $limit\n    nextToken: $nextToken\n  ) {\n    __typename\n    items {\n      __typename\n      id\n      orgId\n      badgeNumber\n      title\n      detail\n      location\n      notes\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var badgeNumber: String
  public var updatedAt: ModelStringKeyConditionInput?
  public var sortDirection: ModelSortDirection?
  public var filter: ModelOfficerAssignmentFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(badgeNumber: String, updatedAt: ModelStringKeyConditionInput? = nil, sortDirection: ModelSortDirection? = nil, filter: ModelOfficerAssignmentFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.badgeNumber = badgeNumber
    self.updatedAt = updatedAt
    self.sortDirection = sortDirection
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["badgeNumber": badgeNumber, "updatedAt": updatedAt, "sortDirection": sortDirection, "filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("assignmentsByOfficer", arguments: ["badgeNumber": GraphQLVariable("badgeNumber"), "updatedAt": GraphQLVariable("updatedAt"), "sortDirection": GraphQLVariable("sortDirection"), "filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(AssignmentsByOfficer.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(assignmentsByOfficer: AssignmentsByOfficer? = nil) {
      self.init(snapshot: ["__typename": "Query", "assignmentsByOfficer": assignmentsByOfficer.flatMap { $0.snapshot }])
    }

    public var assignmentsByOfficer: AssignmentsByOfficer? {
      get {
        return (snapshot["assignmentsByOfficer"] as? Snapshot).flatMap { AssignmentsByOfficer(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "assignmentsByOfficer")
      }
    }

    public struct AssignmentsByOfficer: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelOfficerAssignmentConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelOfficerAssignmentConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["OfficerAssignment"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
          GraphQLField("badgeNumber", type: .nonNull(.scalar(String.self))),
          GraphQLField("title", type: .nonNull(.scalar(String.self))),
          GraphQLField("detail", type: .scalar(String.self)),
          GraphQLField("location", type: .scalar(String.self)),
          GraphQLField("notes", type: .scalar(String.self)),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, orgId: String, badgeNumber: String, title: String, detail: String? = nil, location: String? = nil, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
          self.init(snapshot: ["__typename": "OfficerAssignment", "id": id, "orgId": orgId, "badgeNumber": badgeNumber, "title": title, "detail": detail, "location": location, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var orgId: String {
          get {
            return snapshot["orgId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "orgId")
          }
        }

        public var badgeNumber: String {
          get {
            return snapshot["badgeNumber"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "badgeNumber")
          }
        }

        public var title: String {
          get {
            return snapshot["title"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "title")
          }
        }

        public var detail: String? {
          get {
            return snapshot["detail"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "detail")
          }
        }

        public var location: String? {
          get {
            return snapshot["location"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "location")
          }
        }

        public var notes: String? {
          get {
            return snapshot["notes"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "notes")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String? {
          get {
            return snapshot["updatedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class GetOvertimePostingQuery: GraphQLQuery {
  public static let operationString =
    "query GetOvertimePosting($id: ID!) {\n  getOvertimePosting(id: $id) {\n    __typename\n    id\n    orgId\n    title\n    location\n    scenario\n    startsAt\n    endsAt\n    slots\n    policySnapshot\n    selectionPolicy\n    needsEscalation\n    state\n    createdBy\n    invites {\n      __typename\n      nextToken\n    }\n    auditTrail {\n      __typename\n      nextToken\n    }\n    createdAt\n    updatedAt\n  }\n}"

  public var id: GraphQLID

  public init(id: GraphQLID) {
    self.id = id
  }

  public var variables: GraphQLMap? {
    return ["id": id]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("getOvertimePosting", arguments: ["id": GraphQLVariable("id")], type: .object(GetOvertimePosting.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(getOvertimePosting: GetOvertimePosting? = nil) {
      self.init(snapshot: ["__typename": "Query", "getOvertimePosting": getOvertimePosting.flatMap { $0.snapshot }])
    }

    public var getOvertimePosting: GetOvertimePosting? {
      get {
        return (snapshot["getOvertimePosting"] as? Snapshot).flatMap { GetOvertimePosting(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "getOvertimePosting")
      }
    }

    public struct GetOvertimePosting: GraphQLSelectionSet {
      public static let possibleTypes = ["OvertimePosting"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("location", type: .scalar(String.self)),
        GraphQLField("scenario", type: .nonNull(.scalar(OvertimeScenario.self))),
        GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("slots", type: .nonNull(.scalar(Int.self))),
        GraphQLField("policySnapshot", type: .nonNull(.scalar(String.self))),
        GraphQLField("selectionPolicy", type: .scalar(OvertimeSelectionPolicy.self)),
        GraphQLField("needsEscalation", type: .scalar(Bool.self)),
        GraphQLField("state", type: .nonNull(.scalar(OvertimePostingState.self))),
        GraphQLField("createdBy", type: .nonNull(.scalar(String.self))),
        GraphQLField("invites", type: .object(Invite.selections)),
        GraphQLField("auditTrail", type: .object(AuditTrail.selections)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, title: String, location: String? = nil, scenario: OvertimeScenario, startsAt: String, endsAt: String, slots: Int, policySnapshot: String, selectionPolicy: OvertimeSelectionPolicy? = nil, needsEscalation: Bool? = nil, state: OvertimePostingState, createdBy: String, invites: Invite? = nil, auditTrail: AuditTrail? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "OvertimePosting", "id": id, "orgId": orgId, "title": title, "location": location, "scenario": scenario, "startsAt": startsAt, "endsAt": endsAt, "slots": slots, "policySnapshot": policySnapshot, "selectionPolicy": selectionPolicy, "needsEscalation": needsEscalation, "state": state, "createdBy": createdBy, "invites": invites.flatMap { $0.snapshot }, "auditTrail": auditTrail.flatMap { $0.snapshot }, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var location: String? {
        get {
          return snapshot["location"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "location")
        }
      }

      public var scenario: OvertimeScenario {
        get {
          return snapshot["scenario"]! as! OvertimeScenario
        }
        set {
          snapshot.updateValue(newValue, forKey: "scenario")
        }
      }

      public var startsAt: String {
        get {
          return snapshot["startsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "startsAt")
        }
      }

      public var endsAt: String {
        get {
          return snapshot["endsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "endsAt")
        }
      }

      public var slots: Int {
        get {
          return snapshot["slots"]! as! Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "slots")
        }
      }

      public var policySnapshot: String {
        get {
          return snapshot["policySnapshot"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "policySnapshot")
        }
      }

      public var selectionPolicy: OvertimeSelectionPolicy? {
        get {
          return snapshot["selectionPolicy"] as? OvertimeSelectionPolicy
        }
        set {
          snapshot.updateValue(newValue, forKey: "selectionPolicy")
        }
      }

      public var needsEscalation: Bool? {
        get {
          return snapshot["needsEscalation"] as? Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "needsEscalation")
        }
      }

      public var state: OvertimePostingState {
        get {
          return snapshot["state"]! as! OvertimePostingState
        }
        set {
          snapshot.updateValue(newValue, forKey: "state")
        }
      }

      public var createdBy: String {
        get {
          return snapshot["createdBy"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdBy")
        }
      }

      public var invites: Invite? {
        get {
          return (snapshot["invites"] as? Snapshot).flatMap { Invite(snapshot: $0) }
        }
        set {
          snapshot.updateValue(newValue?.snapshot, forKey: "invites")
        }
      }

      public var auditTrail: AuditTrail? {
        get {
          return (snapshot["auditTrail"] as? Snapshot).flatMap { AuditTrail(snapshot: $0) }
        }
        set {
          snapshot.updateValue(newValue?.snapshot, forKey: "auditTrail")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }

      public struct Invite: GraphQLSelectionSet {
        public static let possibleTypes = ["ModelOvertimeInviteConnection"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("nextToken", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(nextToken: String? = nil) {
          self.init(snapshot: ["__typename": "ModelOvertimeInviteConnection", "nextToken": nextToken])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var nextToken: String? {
          get {
            return snapshot["nextToken"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "nextToken")
          }
        }
      }

      public struct AuditTrail: GraphQLSelectionSet {
        public static let possibleTypes = ["ModelOvertimeAuditEventConnection"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("nextToken", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(nextToken: String? = nil) {
          self.init(snapshot: ["__typename": "ModelOvertimeAuditEventConnection", "nextToken": nextToken])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var nextToken: String? {
          get {
            return snapshot["nextToken"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "nextToken")
          }
        }
      }
    }
  }
}

public final class ListOvertimePostingsQuery: GraphQLQuery {
  public static let operationString =
    "query ListOvertimePostings($filter: ModelOvertimePostingFilterInput, $limit: Int, $nextToken: String) {\n  listOvertimePostings(filter: $filter, limit: $limit, nextToken: $nextToken) {\n    __typename\n    items {\n      __typename\n      id\n      orgId\n      title\n      location\n      scenario\n      startsAt\n      endsAt\n      slots\n      policySnapshot\n      selectionPolicy\n      needsEscalation\n      state\n      createdBy\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var filter: ModelOvertimePostingFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(filter: ModelOvertimePostingFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("listOvertimePostings", arguments: ["filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(ListOvertimePosting.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(listOvertimePostings: ListOvertimePosting? = nil) {
      self.init(snapshot: ["__typename": "Query", "listOvertimePostings": listOvertimePostings.flatMap { $0.snapshot }])
    }

    public var listOvertimePostings: ListOvertimePosting? {
      get {
        return (snapshot["listOvertimePostings"] as? Snapshot).flatMap { ListOvertimePosting(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "listOvertimePostings")
      }
    }

    public struct ListOvertimePosting: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelOvertimePostingConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelOvertimePostingConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["OvertimePosting"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
          GraphQLField("title", type: .nonNull(.scalar(String.self))),
          GraphQLField("location", type: .scalar(String.self)),
          GraphQLField("scenario", type: .nonNull(.scalar(OvertimeScenario.self))),
          GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
          GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
          GraphQLField("slots", type: .nonNull(.scalar(Int.self))),
          GraphQLField("policySnapshot", type: .nonNull(.scalar(String.self))),
          GraphQLField("selectionPolicy", type: .scalar(OvertimeSelectionPolicy.self)),
          GraphQLField("needsEscalation", type: .scalar(Bool.self)),
          GraphQLField("state", type: .nonNull(.scalar(OvertimePostingState.self))),
          GraphQLField("createdBy", type: .nonNull(.scalar(String.self))),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, orgId: String, title: String, location: String? = nil, scenario: OvertimeScenario, startsAt: String, endsAt: String, slots: Int, policySnapshot: String, selectionPolicy: OvertimeSelectionPolicy? = nil, needsEscalation: Bool? = nil, state: OvertimePostingState, createdBy: String, createdAt: String? = nil, updatedAt: String? = nil) {
          self.init(snapshot: ["__typename": "OvertimePosting", "id": id, "orgId": orgId, "title": title, "location": location, "scenario": scenario, "startsAt": startsAt, "endsAt": endsAt, "slots": slots, "policySnapshot": policySnapshot, "selectionPolicy": selectionPolicy, "needsEscalation": needsEscalation, "state": state, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var orgId: String {
          get {
            return snapshot["orgId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "orgId")
          }
        }

        public var title: String {
          get {
            return snapshot["title"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "title")
          }
        }

        public var location: String? {
          get {
            return snapshot["location"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "location")
          }
        }

        public var scenario: OvertimeScenario {
          get {
            return snapshot["scenario"]! as! OvertimeScenario
          }
          set {
            snapshot.updateValue(newValue, forKey: "scenario")
          }
        }

        public var startsAt: String {
          get {
            return snapshot["startsAt"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "startsAt")
          }
        }

        public var endsAt: String {
          get {
            return snapshot["endsAt"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "endsAt")
          }
        }

        public var slots: Int {
          get {
            return snapshot["slots"]! as! Int
          }
          set {
            snapshot.updateValue(newValue, forKey: "slots")
          }
        }

        public var policySnapshot: String {
          get {
            return snapshot["policySnapshot"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "policySnapshot")
          }
        }

        public var selectionPolicy: OvertimeSelectionPolicy? {
          get {
            return snapshot["selectionPolicy"] as? OvertimeSelectionPolicy
          }
          set {
            snapshot.updateValue(newValue, forKey: "selectionPolicy")
          }
        }

        public var needsEscalation: Bool? {
          get {
            return snapshot["needsEscalation"] as? Bool
          }
          set {
            snapshot.updateValue(newValue, forKey: "needsEscalation")
          }
        }

        public var state: OvertimePostingState {
          get {
            return snapshot["state"]! as! OvertimePostingState
          }
          set {
            snapshot.updateValue(newValue, forKey: "state")
          }
        }

        public var createdBy: String {
          get {
            return snapshot["createdBy"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdBy")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String? {
          get {
            return snapshot["updatedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class OvertimePostingsByOrgQuery: GraphQLQuery {
  public static let operationString =
    "query OvertimePostingsByOrg($orgId: String!, $startsAt: ModelStringKeyConditionInput, $sortDirection: ModelSortDirection, $filter: ModelOvertimePostingFilterInput, $limit: Int, $nextToken: String) {\n  overtimePostingsByOrg(\n    orgId: $orgId\n    startsAt: $startsAt\n    sortDirection: $sortDirection\n    filter: $filter\n    limit: $limit\n    nextToken: $nextToken\n  ) {\n    __typename\n    items {\n      __typename\n      id\n      orgId\n      title\n      location\n      scenario\n      startsAt\n      endsAt\n      slots\n      policySnapshot\n      selectionPolicy\n      needsEscalation\n      state\n      createdBy\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var orgId: String
  public var startsAt: ModelStringKeyConditionInput?
  public var sortDirection: ModelSortDirection?
  public var filter: ModelOvertimePostingFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(orgId: String, startsAt: ModelStringKeyConditionInput? = nil, sortDirection: ModelSortDirection? = nil, filter: ModelOvertimePostingFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.orgId = orgId
    self.startsAt = startsAt
    self.sortDirection = sortDirection
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["orgId": orgId, "startsAt": startsAt, "sortDirection": sortDirection, "filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("overtimePostingsByOrg", arguments: ["orgId": GraphQLVariable("orgId"), "startsAt": GraphQLVariable("startsAt"), "sortDirection": GraphQLVariable("sortDirection"), "filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(OvertimePostingsByOrg.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(overtimePostingsByOrg: OvertimePostingsByOrg? = nil) {
      self.init(snapshot: ["__typename": "Query", "overtimePostingsByOrg": overtimePostingsByOrg.flatMap { $0.snapshot }])
    }

    public var overtimePostingsByOrg: OvertimePostingsByOrg? {
      get {
        return (snapshot["overtimePostingsByOrg"] as? Snapshot).flatMap { OvertimePostingsByOrg(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "overtimePostingsByOrg")
      }
    }

    public struct OvertimePostingsByOrg: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelOvertimePostingConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelOvertimePostingConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["OvertimePosting"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
          GraphQLField("title", type: .nonNull(.scalar(String.self))),
          GraphQLField("location", type: .scalar(String.self)),
          GraphQLField("scenario", type: .nonNull(.scalar(OvertimeScenario.self))),
          GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
          GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
          GraphQLField("slots", type: .nonNull(.scalar(Int.self))),
          GraphQLField("policySnapshot", type: .nonNull(.scalar(String.self))),
          GraphQLField("selectionPolicy", type: .scalar(OvertimeSelectionPolicy.self)),
          GraphQLField("needsEscalation", type: .scalar(Bool.self)),
          GraphQLField("state", type: .nonNull(.scalar(OvertimePostingState.self))),
          GraphQLField("createdBy", type: .nonNull(.scalar(String.self))),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, orgId: String, title: String, location: String? = nil, scenario: OvertimeScenario, startsAt: String, endsAt: String, slots: Int, policySnapshot: String, selectionPolicy: OvertimeSelectionPolicy? = nil, needsEscalation: Bool? = nil, state: OvertimePostingState, createdBy: String, createdAt: String? = nil, updatedAt: String? = nil) {
          self.init(snapshot: ["__typename": "OvertimePosting", "id": id, "orgId": orgId, "title": title, "location": location, "scenario": scenario, "startsAt": startsAt, "endsAt": endsAt, "slots": slots, "policySnapshot": policySnapshot, "selectionPolicy": selectionPolicy, "needsEscalation": needsEscalation, "state": state, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var orgId: String {
          get {
            return snapshot["orgId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "orgId")
          }
        }

        public var title: String {
          get {
            return snapshot["title"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "title")
          }
        }

        public var location: String? {
          get {
            return snapshot["location"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "location")
          }
        }

        public var scenario: OvertimeScenario {
          get {
            return snapshot["scenario"]! as! OvertimeScenario
          }
          set {
            snapshot.updateValue(newValue, forKey: "scenario")
          }
        }

        public var startsAt: String {
          get {
            return snapshot["startsAt"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "startsAt")
          }
        }

        public var endsAt: String {
          get {
            return snapshot["endsAt"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "endsAt")
          }
        }

        public var slots: Int {
          get {
            return snapshot["slots"]! as! Int
          }
          set {
            snapshot.updateValue(newValue, forKey: "slots")
          }
        }

        public var policySnapshot: String {
          get {
            return snapshot["policySnapshot"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "policySnapshot")
          }
        }

        public var selectionPolicy: OvertimeSelectionPolicy? {
          get {
            return snapshot["selectionPolicy"] as? OvertimeSelectionPolicy
          }
          set {
            snapshot.updateValue(newValue, forKey: "selectionPolicy")
          }
        }

        public var needsEscalation: Bool? {
          get {
            return snapshot["needsEscalation"] as? Bool
          }
          set {
            snapshot.updateValue(newValue, forKey: "needsEscalation")
          }
        }

        public var state: OvertimePostingState {
          get {
            return snapshot["state"]! as! OvertimePostingState
          }
          set {
            snapshot.updateValue(newValue, forKey: "state")
          }
        }

        public var createdBy: String {
          get {
            return snapshot["createdBy"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdBy")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String? {
          get {
            return snapshot["updatedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class GetOvertimeInviteQuery: GraphQLQuery {
  public static let operationString =
    "query GetOvertimeInvite($id: ID!) {\n  getOvertimeInvite(id: $id) {\n    __typename\n    id\n    postingId\n    officerId\n    bucket\n    sequence\n    reason\n    status\n    respondedAt\n    createdAt\n    updatedAt\n  }\n}"

  public var id: GraphQLID

  public init(id: GraphQLID) {
    self.id = id
  }

  public var variables: GraphQLMap? {
    return ["id": id]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("getOvertimeInvite", arguments: ["id": GraphQLVariable("id")], type: .object(GetOvertimeInvite.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(getOvertimeInvite: GetOvertimeInvite? = nil) {
      self.init(snapshot: ["__typename": "Query", "getOvertimeInvite": getOvertimeInvite.flatMap { $0.snapshot }])
    }

    public var getOvertimeInvite: GetOvertimeInvite? {
      get {
        return (snapshot["getOvertimeInvite"] as? Snapshot).flatMap { GetOvertimeInvite(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "getOvertimeInvite")
      }
    }

    public struct GetOvertimeInvite: GraphQLSelectionSet {
      public static let possibleTypes = ["OvertimeInvite"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("postingId", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("officerId", type: .nonNull(.scalar(String.self))),
        GraphQLField("bucket", type: .nonNull(.scalar(String.self))),
        GraphQLField("sequence", type: .nonNull(.scalar(Int.self))),
        GraphQLField("reason", type: .nonNull(.scalar(String.self))),
        GraphQLField("status", type: .nonNull(.scalar(OvertimeInviteStatus.self))),
        GraphQLField("respondedAt", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, postingId: GraphQLID, officerId: String, bucket: String, sequence: Int, reason: String, status: OvertimeInviteStatus, respondedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "OvertimeInvite", "id": id, "postingId": postingId, "officerId": officerId, "bucket": bucket, "sequence": sequence, "reason": reason, "status": status, "respondedAt": respondedAt, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var postingId: GraphQLID {
        get {
          return snapshot["postingId"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "postingId")
        }
      }

      public var officerId: String {
        get {
          return snapshot["officerId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "officerId")
        }
      }

      public var bucket: String {
        get {
          return snapshot["bucket"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "bucket")
        }
      }

      public var sequence: Int {
        get {
          return snapshot["sequence"]! as! Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "sequence")
        }
      }

      public var reason: String {
        get {
          return snapshot["reason"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "reason")
        }
      }

      public var status: OvertimeInviteStatus {
        get {
          return snapshot["status"]! as! OvertimeInviteStatus
        }
        set {
          snapshot.updateValue(newValue, forKey: "status")
        }
      }

      public var respondedAt: String? {
        get {
          return snapshot["respondedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "respondedAt")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class ListOvertimeInvitesQuery: GraphQLQuery {
  public static let operationString =
    "query ListOvertimeInvites($filter: ModelOvertimeInviteFilterInput, $limit: Int, $nextToken: String) {\n  listOvertimeInvites(filter: $filter, limit: $limit, nextToken: $nextToken) {\n    __typename\n    items {\n      __typename\n      id\n      postingId\n      officerId\n      bucket\n      sequence\n      reason\n      status\n      respondedAt\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var filter: ModelOvertimeInviteFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(filter: ModelOvertimeInviteFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("listOvertimeInvites", arguments: ["filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(ListOvertimeInvite.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(listOvertimeInvites: ListOvertimeInvite? = nil) {
      self.init(snapshot: ["__typename": "Query", "listOvertimeInvites": listOvertimeInvites.flatMap { $0.snapshot }])
    }

    public var listOvertimeInvites: ListOvertimeInvite? {
      get {
        return (snapshot["listOvertimeInvites"] as? Snapshot).flatMap { ListOvertimeInvite(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "listOvertimeInvites")
      }
    }

    public struct ListOvertimeInvite: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelOvertimeInviteConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelOvertimeInviteConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["OvertimeInvite"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("postingId", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("officerId", type: .nonNull(.scalar(String.self))),
          GraphQLField("bucket", type: .nonNull(.scalar(String.self))),
          GraphQLField("sequence", type: .nonNull(.scalar(Int.self))),
          GraphQLField("reason", type: .nonNull(.scalar(String.self))),
          GraphQLField("status", type: .nonNull(.scalar(OvertimeInviteStatus.self))),
          GraphQLField("respondedAt", type: .scalar(String.self)),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, postingId: GraphQLID, officerId: String, bucket: String, sequence: Int, reason: String, status: OvertimeInviteStatus, respondedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
          self.init(snapshot: ["__typename": "OvertimeInvite", "id": id, "postingId": postingId, "officerId": officerId, "bucket": bucket, "sequence": sequence, "reason": reason, "status": status, "respondedAt": respondedAt, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var postingId: GraphQLID {
          get {
            return snapshot["postingId"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "postingId")
          }
        }

        public var officerId: String {
          get {
            return snapshot["officerId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "officerId")
          }
        }

        public var bucket: String {
          get {
            return snapshot["bucket"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "bucket")
          }
        }

        public var sequence: Int {
          get {
            return snapshot["sequence"]! as! Int
          }
          set {
            snapshot.updateValue(newValue, forKey: "sequence")
          }
        }

        public var reason: String {
          get {
            return snapshot["reason"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "reason")
          }
        }

        public var status: OvertimeInviteStatus {
          get {
            return snapshot["status"]! as! OvertimeInviteStatus
          }
          set {
            snapshot.updateValue(newValue, forKey: "status")
          }
        }

        public var respondedAt: String? {
          get {
            return snapshot["respondedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "respondedAt")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String? {
          get {
            return snapshot["updatedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class InvitesByPostingQuery: GraphQLQuery {
  public static let operationString =
    "query InvitesByPosting($postingId: ID!, $sequence: ModelIntKeyConditionInput, $sortDirection: ModelSortDirection, $filter: ModelOvertimeInviteFilterInput, $limit: Int, $nextToken: String) {\n  invitesByPosting(\n    postingId: $postingId\n    sequence: $sequence\n    sortDirection: $sortDirection\n    filter: $filter\n    limit: $limit\n    nextToken: $nextToken\n  ) {\n    __typename\n    items {\n      __typename\n      id\n      postingId\n      officerId\n      bucket\n      sequence\n      reason\n      status\n      respondedAt\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var postingId: GraphQLID
  public var sequence: ModelIntKeyConditionInput?
  public var sortDirection: ModelSortDirection?
  public var filter: ModelOvertimeInviteFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(postingId: GraphQLID, sequence: ModelIntKeyConditionInput? = nil, sortDirection: ModelSortDirection? = nil, filter: ModelOvertimeInviteFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.postingId = postingId
    self.sequence = sequence
    self.sortDirection = sortDirection
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["postingId": postingId, "sequence": sequence, "sortDirection": sortDirection, "filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("invitesByPosting", arguments: ["postingId": GraphQLVariable("postingId"), "sequence": GraphQLVariable("sequence"), "sortDirection": GraphQLVariable("sortDirection"), "filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(InvitesByPosting.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(invitesByPosting: InvitesByPosting? = nil) {
      self.init(snapshot: ["__typename": "Query", "invitesByPosting": invitesByPosting.flatMap { $0.snapshot }])
    }

    public var invitesByPosting: InvitesByPosting? {
      get {
        return (snapshot["invitesByPosting"] as? Snapshot).flatMap { InvitesByPosting(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "invitesByPosting")
      }
    }

    public struct InvitesByPosting: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelOvertimeInviteConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelOvertimeInviteConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["OvertimeInvite"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("postingId", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("officerId", type: .nonNull(.scalar(String.self))),
          GraphQLField("bucket", type: .nonNull(.scalar(String.self))),
          GraphQLField("sequence", type: .nonNull(.scalar(Int.self))),
          GraphQLField("reason", type: .nonNull(.scalar(String.self))),
          GraphQLField("status", type: .nonNull(.scalar(OvertimeInviteStatus.self))),
          GraphQLField("respondedAt", type: .scalar(String.self)),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, postingId: GraphQLID, officerId: String, bucket: String, sequence: Int, reason: String, status: OvertimeInviteStatus, respondedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
          self.init(snapshot: ["__typename": "OvertimeInvite", "id": id, "postingId": postingId, "officerId": officerId, "bucket": bucket, "sequence": sequence, "reason": reason, "status": status, "respondedAt": respondedAt, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var postingId: GraphQLID {
          get {
            return snapshot["postingId"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "postingId")
          }
        }

        public var officerId: String {
          get {
            return snapshot["officerId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "officerId")
          }
        }

        public var bucket: String {
          get {
            return snapshot["bucket"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "bucket")
          }
        }

        public var sequence: Int {
          get {
            return snapshot["sequence"]! as! Int
          }
          set {
            snapshot.updateValue(newValue, forKey: "sequence")
          }
        }

        public var reason: String {
          get {
            return snapshot["reason"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "reason")
          }
        }

        public var status: OvertimeInviteStatus {
          get {
            return snapshot["status"]! as! OvertimeInviteStatus
          }
          set {
            snapshot.updateValue(newValue, forKey: "status")
          }
        }

        public var respondedAt: String? {
          get {
            return snapshot["respondedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "respondedAt")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String? {
          get {
            return snapshot["updatedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class GetOvertimeAuditEventQuery: GraphQLQuery {
  public static let operationString =
    "query GetOvertimeAuditEvent($id: ID!) {\n  getOvertimeAuditEvent(id: $id) {\n    __typename\n    id\n    postingId\n    type\n    details\n    createdBy\n    createdAt\n    updatedAt\n  }\n}"

  public var id: GraphQLID

  public init(id: GraphQLID) {
    self.id = id
  }

  public var variables: GraphQLMap? {
    return ["id": id]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("getOvertimeAuditEvent", arguments: ["id": GraphQLVariable("id")], type: .object(GetOvertimeAuditEvent.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(getOvertimeAuditEvent: GetOvertimeAuditEvent? = nil) {
      self.init(snapshot: ["__typename": "Query", "getOvertimeAuditEvent": getOvertimeAuditEvent.flatMap { $0.snapshot }])
    }

    public var getOvertimeAuditEvent: GetOvertimeAuditEvent? {
      get {
        return (snapshot["getOvertimeAuditEvent"] as? Snapshot).flatMap { GetOvertimeAuditEvent(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "getOvertimeAuditEvent")
      }
    }

    public struct GetOvertimeAuditEvent: GraphQLSelectionSet {
      public static let possibleTypes = ["OvertimeAuditEvent"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("postingId", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("type", type: .nonNull(.scalar(String.self))),
        GraphQLField("details", type: .scalar(String.self)),
        GraphQLField("createdBy", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .nonNull(.scalar(String.self))),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, postingId: GraphQLID, type: String, details: String? = nil, createdBy: String? = nil, createdAt: String? = nil, updatedAt: String) {
        self.init(snapshot: ["__typename": "OvertimeAuditEvent", "id": id, "postingId": postingId, "type": type, "details": details, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var postingId: GraphQLID {
        get {
          return snapshot["postingId"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "postingId")
        }
      }

      public var type: String {
        get {
          return snapshot["type"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "type")
        }
      }

      public var details: String? {
        get {
          return snapshot["details"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "details")
        }
      }

      public var createdBy: String? {
        get {
          return snapshot["createdBy"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdBy")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String {
        get {
          return snapshot["updatedAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class ListOvertimeAuditEventsQuery: GraphQLQuery {
  public static let operationString =
    "query ListOvertimeAuditEvents($filter: ModelOvertimeAuditEventFilterInput, $limit: Int, $nextToken: String) {\n  listOvertimeAuditEvents(filter: $filter, limit: $limit, nextToken: $nextToken) {\n    __typename\n    items {\n      __typename\n      id\n      postingId\n      type\n      details\n      createdBy\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var filter: ModelOvertimeAuditEventFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(filter: ModelOvertimeAuditEventFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("listOvertimeAuditEvents", arguments: ["filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(ListOvertimeAuditEvent.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(listOvertimeAuditEvents: ListOvertimeAuditEvent? = nil) {
      self.init(snapshot: ["__typename": "Query", "listOvertimeAuditEvents": listOvertimeAuditEvents.flatMap { $0.snapshot }])
    }

    public var listOvertimeAuditEvents: ListOvertimeAuditEvent? {
      get {
        return (snapshot["listOvertimeAuditEvents"] as? Snapshot).flatMap { ListOvertimeAuditEvent(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "listOvertimeAuditEvents")
      }
    }

    public struct ListOvertimeAuditEvent: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelOvertimeAuditEventConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelOvertimeAuditEventConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["OvertimeAuditEvent"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("postingId", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("type", type: .nonNull(.scalar(String.self))),
          GraphQLField("details", type: .scalar(String.self)),
          GraphQLField("createdBy", type: .scalar(String.self)),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .nonNull(.scalar(String.self))),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, postingId: GraphQLID, type: String, details: String? = nil, createdBy: String? = nil, createdAt: String? = nil, updatedAt: String) {
          self.init(snapshot: ["__typename": "OvertimeAuditEvent", "id": id, "postingId": postingId, "type": type, "details": details, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var postingId: GraphQLID {
          get {
            return snapshot["postingId"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "postingId")
          }
        }

        public var type: String {
          get {
            return snapshot["type"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "type")
          }
        }

        public var details: String? {
          get {
            return snapshot["details"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "details")
          }
        }

        public var createdBy: String? {
          get {
            return snapshot["createdBy"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdBy")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String {
          get {
            return snapshot["updatedAt"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class AuditsByPostingQuery: GraphQLQuery {
  public static let operationString =
    "query AuditsByPosting($postingId: ID!, $createdAt: ModelStringKeyConditionInput, $sortDirection: ModelSortDirection, $filter: ModelOvertimeAuditEventFilterInput, $limit: Int, $nextToken: String) {\n  auditsByPosting(\n    postingId: $postingId\n    createdAt: $createdAt\n    sortDirection: $sortDirection\n    filter: $filter\n    limit: $limit\n    nextToken: $nextToken\n  ) {\n    __typename\n    items {\n      __typename\n      id\n      postingId\n      type\n      details\n      createdBy\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var postingId: GraphQLID
  public var createdAt: ModelStringKeyConditionInput?
  public var sortDirection: ModelSortDirection?
  public var filter: ModelOvertimeAuditEventFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(postingId: GraphQLID, createdAt: ModelStringKeyConditionInput? = nil, sortDirection: ModelSortDirection? = nil, filter: ModelOvertimeAuditEventFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.postingId = postingId
    self.createdAt = createdAt
    self.sortDirection = sortDirection
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["postingId": postingId, "createdAt": createdAt, "sortDirection": sortDirection, "filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("auditsByPosting", arguments: ["postingId": GraphQLVariable("postingId"), "createdAt": GraphQLVariable("createdAt"), "sortDirection": GraphQLVariable("sortDirection"), "filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(AuditsByPosting.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(auditsByPosting: AuditsByPosting? = nil) {
      self.init(snapshot: ["__typename": "Query", "auditsByPosting": auditsByPosting.flatMap { $0.snapshot }])
    }

    public var auditsByPosting: AuditsByPosting? {
      get {
        return (snapshot["auditsByPosting"] as? Snapshot).flatMap { AuditsByPosting(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "auditsByPosting")
      }
    }

    public struct AuditsByPosting: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelOvertimeAuditEventConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelOvertimeAuditEventConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["OvertimeAuditEvent"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("postingId", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("type", type: .nonNull(.scalar(String.self))),
          GraphQLField("details", type: .scalar(String.self)),
          GraphQLField("createdBy", type: .scalar(String.self)),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .nonNull(.scalar(String.self))),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, postingId: GraphQLID, type: String, details: String? = nil, createdBy: String? = nil, createdAt: String? = nil, updatedAt: String) {
          self.init(snapshot: ["__typename": "OvertimeAuditEvent", "id": id, "postingId": postingId, "type": type, "details": details, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var postingId: GraphQLID {
          get {
            return snapshot["postingId"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "postingId")
          }
        }

        public var type: String {
          get {
            return snapshot["type"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "type")
          }
        }

        public var details: String? {
          get {
            return snapshot["details"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "details")
          }
        }

        public var createdBy: String? {
          get {
            return snapshot["createdBy"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdBy")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String {
          get {
            return snapshot["updatedAt"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class GetNotificationEndpointQuery: GraphQLQuery {
  public static let operationString =
    "query GetNotificationEndpoint($id: ID!) {\n  getNotificationEndpoint(id: $id) {\n    __typename\n    id\n    orgId\n    userId\n    deviceToken\n    platform\n    deviceName\n    enabled\n    platformEndpointArn\n    lastUsedAt\n    createdAt\n    updatedAt\n  }\n}"

  public var id: GraphQLID

  public init(id: GraphQLID) {
    self.id = id
  }

  public var variables: GraphQLMap? {
    return ["id": id]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("getNotificationEndpoint", arguments: ["id": GraphQLVariable("id")], type: .object(GetNotificationEndpoint.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(getNotificationEndpoint: GetNotificationEndpoint? = nil) {
      self.init(snapshot: ["__typename": "Query", "getNotificationEndpoint": getNotificationEndpoint.flatMap { $0.snapshot }])
    }

    public var getNotificationEndpoint: GetNotificationEndpoint? {
      get {
        return (snapshot["getNotificationEndpoint"] as? Snapshot).flatMap { GetNotificationEndpoint(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "getNotificationEndpoint")
      }
    }

    public struct GetNotificationEndpoint: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationEndpoint"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("userId", type: .nonNull(.scalar(String.self))),
        GraphQLField("deviceToken", type: .nonNull(.scalar(String.self))),
        GraphQLField("platform", type: .nonNull(.scalar(NotificationPlatform.self))),
        GraphQLField("deviceName", type: .scalar(String.self)),
        GraphQLField("enabled", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("platformEndpointArn", type: .scalar(String.self)),
        GraphQLField("lastUsedAt", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, userId: String, deviceToken: String, platform: NotificationPlatform, deviceName: String? = nil, enabled: Bool, platformEndpointArn: String? = nil, lastUsedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationEndpoint", "id": id, "orgId": orgId, "userId": userId, "deviceToken": deviceToken, "platform": platform, "deviceName": deviceName, "enabled": enabled, "platformEndpointArn": platformEndpointArn, "lastUsedAt": lastUsedAt, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var userId: String {
        get {
          return snapshot["userId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "userId")
        }
      }

      public var deviceToken: String {
        get {
          return snapshot["deviceToken"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "deviceToken")
        }
      }

      public var platform: NotificationPlatform {
        get {
          return snapshot["platform"]! as! NotificationPlatform
        }
        set {
          snapshot.updateValue(newValue, forKey: "platform")
        }
      }

      public var deviceName: String? {
        get {
          return snapshot["deviceName"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "deviceName")
        }
      }

      public var enabled: Bool {
        get {
          return snapshot["enabled"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "enabled")
        }
      }

      public var platformEndpointArn: String? {
        get {
          return snapshot["platformEndpointArn"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "platformEndpointArn")
        }
      }

      public var lastUsedAt: String? {
        get {
          return snapshot["lastUsedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "lastUsedAt")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class ListNotificationEndpointsQuery: GraphQLQuery {
  public static let operationString =
    "query ListNotificationEndpoints($filter: ModelNotificationEndpointFilterInput, $limit: Int, $nextToken: String) {\n  listNotificationEndpoints(filter: $filter, limit: $limit, nextToken: $nextToken) {\n    __typename\n    items {\n      __typename\n      id\n      orgId\n      userId\n      deviceToken\n      platform\n      deviceName\n      enabled\n      platformEndpointArn\n      lastUsedAt\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var filter: ModelNotificationEndpointFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(filter: ModelNotificationEndpointFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("listNotificationEndpoints", arguments: ["filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(ListNotificationEndpoint.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(listNotificationEndpoints: ListNotificationEndpoint? = nil) {
      self.init(snapshot: ["__typename": "Query", "listNotificationEndpoints": listNotificationEndpoints.flatMap { $0.snapshot }])
    }

    public var listNotificationEndpoints: ListNotificationEndpoint? {
      get {
        return (snapshot["listNotificationEndpoints"] as? Snapshot).flatMap { ListNotificationEndpoint(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "listNotificationEndpoints")
      }
    }

    public struct ListNotificationEndpoint: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelNotificationEndpointConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelNotificationEndpointConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["NotificationEndpoint"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
          GraphQLField("userId", type: .nonNull(.scalar(String.self))),
          GraphQLField("deviceToken", type: .nonNull(.scalar(String.self))),
          GraphQLField("platform", type: .nonNull(.scalar(NotificationPlatform.self))),
          GraphQLField("deviceName", type: .scalar(String.self)),
          GraphQLField("enabled", type: .nonNull(.scalar(Bool.self))),
          GraphQLField("platformEndpointArn", type: .scalar(String.self)),
          GraphQLField("lastUsedAt", type: .scalar(String.self)),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, orgId: String, userId: String, deviceToken: String, platform: NotificationPlatform, deviceName: String? = nil, enabled: Bool, platformEndpointArn: String? = nil, lastUsedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
          self.init(snapshot: ["__typename": "NotificationEndpoint", "id": id, "orgId": orgId, "userId": userId, "deviceToken": deviceToken, "platform": platform, "deviceName": deviceName, "enabled": enabled, "platformEndpointArn": platformEndpointArn, "lastUsedAt": lastUsedAt, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var orgId: String {
          get {
            return snapshot["orgId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "orgId")
          }
        }

        public var userId: String {
          get {
            return snapshot["userId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "userId")
          }
        }

        public var deviceToken: String {
          get {
            return snapshot["deviceToken"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "deviceToken")
          }
        }

        public var platform: NotificationPlatform {
          get {
            return snapshot["platform"]! as! NotificationPlatform
          }
          set {
            snapshot.updateValue(newValue, forKey: "platform")
          }
        }

        public var deviceName: String? {
          get {
            return snapshot["deviceName"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "deviceName")
          }
        }

        public var enabled: Bool {
          get {
            return snapshot["enabled"]! as! Bool
          }
          set {
            snapshot.updateValue(newValue, forKey: "enabled")
          }
        }

        public var platformEndpointArn: String? {
          get {
            return snapshot["platformEndpointArn"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "platformEndpointArn")
          }
        }

        public var lastUsedAt: String? {
          get {
            return snapshot["lastUsedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "lastUsedAt")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String? {
          get {
            return snapshot["updatedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class NotificationEndpointsByOrgQuery: GraphQLQuery {
  public static let operationString =
    "query NotificationEndpointsByOrg($orgId: String!, $updatedAt: ModelStringKeyConditionInput, $sortDirection: ModelSortDirection, $filter: ModelNotificationEndpointFilterInput, $limit: Int, $nextToken: String) {\n  notificationEndpointsByOrg(\n    orgId: $orgId\n    updatedAt: $updatedAt\n    sortDirection: $sortDirection\n    filter: $filter\n    limit: $limit\n    nextToken: $nextToken\n  ) {\n    __typename\n    items {\n      __typename\n      id\n      orgId\n      userId\n      deviceToken\n      platform\n      deviceName\n      enabled\n      platformEndpointArn\n      lastUsedAt\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var orgId: String
  public var updatedAt: ModelStringKeyConditionInput?
  public var sortDirection: ModelSortDirection?
  public var filter: ModelNotificationEndpointFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(orgId: String, updatedAt: ModelStringKeyConditionInput? = nil, sortDirection: ModelSortDirection? = nil, filter: ModelNotificationEndpointFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.orgId = orgId
    self.updatedAt = updatedAt
    self.sortDirection = sortDirection
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["orgId": orgId, "updatedAt": updatedAt, "sortDirection": sortDirection, "filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("notificationEndpointsByOrg", arguments: ["orgId": GraphQLVariable("orgId"), "updatedAt": GraphQLVariable("updatedAt"), "sortDirection": GraphQLVariable("sortDirection"), "filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(NotificationEndpointsByOrg.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(notificationEndpointsByOrg: NotificationEndpointsByOrg? = nil) {
      self.init(snapshot: ["__typename": "Query", "notificationEndpointsByOrg": notificationEndpointsByOrg.flatMap { $0.snapshot }])
    }

    public var notificationEndpointsByOrg: NotificationEndpointsByOrg? {
      get {
        return (snapshot["notificationEndpointsByOrg"] as? Snapshot).flatMap { NotificationEndpointsByOrg(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "notificationEndpointsByOrg")
      }
    }

    public struct NotificationEndpointsByOrg: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelNotificationEndpointConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelNotificationEndpointConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["NotificationEndpoint"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
          GraphQLField("userId", type: .nonNull(.scalar(String.self))),
          GraphQLField("deviceToken", type: .nonNull(.scalar(String.self))),
          GraphQLField("platform", type: .nonNull(.scalar(NotificationPlatform.self))),
          GraphQLField("deviceName", type: .scalar(String.self)),
          GraphQLField("enabled", type: .nonNull(.scalar(Bool.self))),
          GraphQLField("platformEndpointArn", type: .scalar(String.self)),
          GraphQLField("lastUsedAt", type: .scalar(String.self)),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, orgId: String, userId: String, deviceToken: String, platform: NotificationPlatform, deviceName: String? = nil, enabled: Bool, platformEndpointArn: String? = nil, lastUsedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
          self.init(snapshot: ["__typename": "NotificationEndpoint", "id": id, "orgId": orgId, "userId": userId, "deviceToken": deviceToken, "platform": platform, "deviceName": deviceName, "enabled": enabled, "platformEndpointArn": platformEndpointArn, "lastUsedAt": lastUsedAt, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var orgId: String {
          get {
            return snapshot["orgId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "orgId")
          }
        }

        public var userId: String {
          get {
            return snapshot["userId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "userId")
          }
        }

        public var deviceToken: String {
          get {
            return snapshot["deviceToken"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "deviceToken")
          }
        }

        public var platform: NotificationPlatform {
          get {
            return snapshot["platform"]! as! NotificationPlatform
          }
          set {
            snapshot.updateValue(newValue, forKey: "platform")
          }
        }

        public var deviceName: String? {
          get {
            return snapshot["deviceName"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "deviceName")
          }
        }

        public var enabled: Bool {
          get {
            return snapshot["enabled"]! as! Bool
          }
          set {
            snapshot.updateValue(newValue, forKey: "enabled")
          }
        }

        public var platformEndpointArn: String? {
          get {
            return snapshot["platformEndpointArn"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "platformEndpointArn")
          }
        }

        public var lastUsedAt: String? {
          get {
            return snapshot["lastUsedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "lastUsedAt")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String? {
          get {
            return snapshot["updatedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class NotificationEndpointsByUserQuery: GraphQLQuery {
  public static let operationString =
    "query NotificationEndpointsByUser($userId: String!, $updatedAt: ModelStringKeyConditionInput, $sortDirection: ModelSortDirection, $filter: ModelNotificationEndpointFilterInput, $limit: Int, $nextToken: String) {\n  notificationEndpointsByUser(\n    userId: $userId\n    updatedAt: $updatedAt\n    sortDirection: $sortDirection\n    filter: $filter\n    limit: $limit\n    nextToken: $nextToken\n  ) {\n    __typename\n    items {\n      __typename\n      id\n      orgId\n      userId\n      deviceToken\n      platform\n      deviceName\n      enabled\n      platformEndpointArn\n      lastUsedAt\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var userId: String
  public var updatedAt: ModelStringKeyConditionInput?
  public var sortDirection: ModelSortDirection?
  public var filter: ModelNotificationEndpointFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(userId: String, updatedAt: ModelStringKeyConditionInput? = nil, sortDirection: ModelSortDirection? = nil, filter: ModelNotificationEndpointFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.userId = userId
    self.updatedAt = updatedAt
    self.sortDirection = sortDirection
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["userId": userId, "updatedAt": updatedAt, "sortDirection": sortDirection, "filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("notificationEndpointsByUser", arguments: ["userId": GraphQLVariable("userId"), "updatedAt": GraphQLVariable("updatedAt"), "sortDirection": GraphQLVariable("sortDirection"), "filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(NotificationEndpointsByUser.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(notificationEndpointsByUser: NotificationEndpointsByUser? = nil) {
      self.init(snapshot: ["__typename": "Query", "notificationEndpointsByUser": notificationEndpointsByUser.flatMap { $0.snapshot }])
    }

    public var notificationEndpointsByUser: NotificationEndpointsByUser? {
      get {
        return (snapshot["notificationEndpointsByUser"] as? Snapshot).flatMap { NotificationEndpointsByUser(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "notificationEndpointsByUser")
      }
    }

    public struct NotificationEndpointsByUser: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelNotificationEndpointConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelNotificationEndpointConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["NotificationEndpoint"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
          GraphQLField("userId", type: .nonNull(.scalar(String.self))),
          GraphQLField("deviceToken", type: .nonNull(.scalar(String.self))),
          GraphQLField("platform", type: .nonNull(.scalar(NotificationPlatform.self))),
          GraphQLField("deviceName", type: .scalar(String.self)),
          GraphQLField("enabled", type: .nonNull(.scalar(Bool.self))),
          GraphQLField("platformEndpointArn", type: .scalar(String.self)),
          GraphQLField("lastUsedAt", type: .scalar(String.self)),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, orgId: String, userId: String, deviceToken: String, platform: NotificationPlatform, deviceName: String? = nil, enabled: Bool, platformEndpointArn: String? = nil, lastUsedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
          self.init(snapshot: ["__typename": "NotificationEndpoint", "id": id, "orgId": orgId, "userId": userId, "deviceToken": deviceToken, "platform": platform, "deviceName": deviceName, "enabled": enabled, "platformEndpointArn": platformEndpointArn, "lastUsedAt": lastUsedAt, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var orgId: String {
          get {
            return snapshot["orgId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "orgId")
          }
        }

        public var userId: String {
          get {
            return snapshot["userId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "userId")
          }
        }

        public var deviceToken: String {
          get {
            return snapshot["deviceToken"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "deviceToken")
          }
        }

        public var platform: NotificationPlatform {
          get {
            return snapshot["platform"]! as! NotificationPlatform
          }
          set {
            snapshot.updateValue(newValue, forKey: "platform")
          }
        }

        public var deviceName: String? {
          get {
            return snapshot["deviceName"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "deviceName")
          }
        }

        public var enabled: Bool {
          get {
            return snapshot["enabled"]! as! Bool
          }
          set {
            snapshot.updateValue(newValue, forKey: "enabled")
          }
        }

        public var platformEndpointArn: String? {
          get {
            return snapshot["platformEndpointArn"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "platformEndpointArn")
          }
        }

        public var lastUsedAt: String? {
          get {
            return snapshot["lastUsedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "lastUsedAt")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String? {
          get {
            return snapshot["updatedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class GetNotificationMessageQuery: GraphQLQuery {
  public static let operationString =
    "query GetNotificationMessage($id: ID!) {\n  getNotificationMessage(id: $id) {\n    __typename\n    id\n    orgId\n    title\n    body\n    category\n    recipients\n    metadata\n    createdBy\n    createdAt\n    updatedAt\n  }\n}"

  public var id: GraphQLID

  public init(id: GraphQLID) {
    self.id = id
  }

  public var variables: GraphQLMap? {
    return ["id": id]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("getNotificationMessage", arguments: ["id": GraphQLVariable("id")], type: .object(GetNotificationMessage.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(getNotificationMessage: GetNotificationMessage? = nil) {
      self.init(snapshot: ["__typename": "Query", "getNotificationMessage": getNotificationMessage.flatMap { $0.snapshot }])
    }

    public var getNotificationMessage: GetNotificationMessage? {
      get {
        return (snapshot["getNotificationMessage"] as? Snapshot).flatMap { GetNotificationMessage(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "getNotificationMessage")
      }
    }

    public struct GetNotificationMessage: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationMessage"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("body", type: .nonNull(.scalar(String.self))),
        GraphQLField("category", type: .nonNull(.scalar(NotificationCategory.self))),
        GraphQLField("recipients", type: .nonNull(.list(.nonNull(.scalar(String.self))))),
        GraphQLField("metadata", type: .scalar(String.self)),
        GraphQLField("createdBy", type: .nonNull(.scalar(String.self))),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, title: String, body: String, category: NotificationCategory, recipients: [String], metadata: String? = nil, createdBy: String, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationMessage", "id": id, "orgId": orgId, "title": title, "body": body, "category": category, "recipients": recipients, "metadata": metadata, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var body: String {
        get {
          return snapshot["body"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "body")
        }
      }

      public var category: NotificationCategory {
        get {
          return snapshot["category"]! as! NotificationCategory
        }
        set {
          snapshot.updateValue(newValue, forKey: "category")
        }
      }

      public var recipients: [String] {
        get {
          return snapshot["recipients"]! as! [String]
        }
        set {
          snapshot.updateValue(newValue, forKey: "recipients")
        }
      }

      public var metadata: String? {
        get {
          return snapshot["metadata"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "metadata")
        }
      }

      public var createdBy: String {
        get {
          return snapshot["createdBy"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdBy")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class ListNotificationMessagesQuery: GraphQLQuery {
  public static let operationString =
    "query ListNotificationMessages($filter: ModelNotificationMessageFilterInput, $limit: Int, $nextToken: String) {\n  listNotificationMessages(filter: $filter, limit: $limit, nextToken: $nextToken) {\n    __typename\n    items {\n      __typename\n      id\n      orgId\n      title\n      body\n      category\n      recipients\n      metadata\n      createdBy\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var filter: ModelNotificationMessageFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(filter: ModelNotificationMessageFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("listNotificationMessages", arguments: ["filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(ListNotificationMessage.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(listNotificationMessages: ListNotificationMessage? = nil) {
      self.init(snapshot: ["__typename": "Query", "listNotificationMessages": listNotificationMessages.flatMap { $0.snapshot }])
    }

    public var listNotificationMessages: ListNotificationMessage? {
      get {
        return (snapshot["listNotificationMessages"] as? Snapshot).flatMap { ListNotificationMessage(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "listNotificationMessages")
      }
    }

    public struct ListNotificationMessage: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelNotificationMessageConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelNotificationMessageConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["NotificationMessage"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
          GraphQLField("title", type: .nonNull(.scalar(String.self))),
          GraphQLField("body", type: .nonNull(.scalar(String.self))),
          GraphQLField("category", type: .nonNull(.scalar(NotificationCategory.self))),
          GraphQLField("recipients", type: .nonNull(.list(.nonNull(.scalar(String.self))))),
          GraphQLField("metadata", type: .scalar(String.self)),
          GraphQLField("createdBy", type: .nonNull(.scalar(String.self))),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, orgId: String, title: String, body: String, category: NotificationCategory, recipients: [String], metadata: String? = nil, createdBy: String, createdAt: String? = nil, updatedAt: String? = nil) {
          self.init(snapshot: ["__typename": "NotificationMessage", "id": id, "orgId": orgId, "title": title, "body": body, "category": category, "recipients": recipients, "metadata": metadata, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var orgId: String {
          get {
            return snapshot["orgId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "orgId")
          }
        }

        public var title: String {
          get {
            return snapshot["title"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "title")
          }
        }

        public var body: String {
          get {
            return snapshot["body"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "body")
          }
        }

        public var category: NotificationCategory {
          get {
            return snapshot["category"]! as! NotificationCategory
          }
          set {
            snapshot.updateValue(newValue, forKey: "category")
          }
        }

        public var recipients: [String] {
          get {
            return snapshot["recipients"]! as! [String]
          }
          set {
            snapshot.updateValue(newValue, forKey: "recipients")
          }
        }

        public var metadata: String? {
          get {
            return snapshot["metadata"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "metadata")
          }
        }

        public var createdBy: String {
          get {
            return snapshot["createdBy"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdBy")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String? {
          get {
            return snapshot["updatedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class NotificationMessagesByOrgQuery: GraphQLQuery {
  public static let operationString =
    "query NotificationMessagesByOrg($orgId: String!, $createdAt: ModelStringKeyConditionInput, $sortDirection: ModelSortDirection, $filter: ModelNotificationMessageFilterInput, $limit: Int, $nextToken: String) {\n  notificationMessagesByOrg(\n    orgId: $orgId\n    createdAt: $createdAt\n    sortDirection: $sortDirection\n    filter: $filter\n    limit: $limit\n    nextToken: $nextToken\n  ) {\n    __typename\n    items {\n      __typename\n      id\n      orgId\n      title\n      body\n      category\n      recipients\n      metadata\n      createdBy\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var orgId: String
  public var createdAt: ModelStringKeyConditionInput?
  public var sortDirection: ModelSortDirection?
  public var filter: ModelNotificationMessageFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(orgId: String, createdAt: ModelStringKeyConditionInput? = nil, sortDirection: ModelSortDirection? = nil, filter: ModelNotificationMessageFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.orgId = orgId
    self.createdAt = createdAt
    self.sortDirection = sortDirection
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["orgId": orgId, "createdAt": createdAt, "sortDirection": sortDirection, "filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("notificationMessagesByOrg", arguments: ["orgId": GraphQLVariable("orgId"), "createdAt": GraphQLVariable("createdAt"), "sortDirection": GraphQLVariable("sortDirection"), "filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(NotificationMessagesByOrg.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(notificationMessagesByOrg: NotificationMessagesByOrg? = nil) {
      self.init(snapshot: ["__typename": "Query", "notificationMessagesByOrg": notificationMessagesByOrg.flatMap { $0.snapshot }])
    }

    public var notificationMessagesByOrg: NotificationMessagesByOrg? {
      get {
        return (snapshot["notificationMessagesByOrg"] as? Snapshot).flatMap { NotificationMessagesByOrg(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "notificationMessagesByOrg")
      }
    }

    public struct NotificationMessagesByOrg: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelNotificationMessageConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelNotificationMessageConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["NotificationMessage"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
          GraphQLField("title", type: .nonNull(.scalar(String.self))),
          GraphQLField("body", type: .nonNull(.scalar(String.self))),
          GraphQLField("category", type: .nonNull(.scalar(NotificationCategory.self))),
          GraphQLField("recipients", type: .nonNull(.list(.nonNull(.scalar(String.self))))),
          GraphQLField("metadata", type: .scalar(String.self)),
          GraphQLField("createdBy", type: .nonNull(.scalar(String.self))),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, orgId: String, title: String, body: String, category: NotificationCategory, recipients: [String], metadata: String? = nil, createdBy: String, createdAt: String? = nil, updatedAt: String? = nil) {
          self.init(snapshot: ["__typename": "NotificationMessage", "id": id, "orgId": orgId, "title": title, "body": body, "category": category, "recipients": recipients, "metadata": metadata, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var orgId: String {
          get {
            return snapshot["orgId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "orgId")
          }
        }

        public var title: String {
          get {
            return snapshot["title"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "title")
          }
        }

        public var body: String {
          get {
            return snapshot["body"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "body")
          }
        }

        public var category: NotificationCategory {
          get {
            return snapshot["category"]! as! NotificationCategory
          }
          set {
            snapshot.updateValue(newValue, forKey: "category")
          }
        }

        public var recipients: [String] {
          get {
            return snapshot["recipients"]! as! [String]
          }
          set {
            snapshot.updateValue(newValue, forKey: "recipients")
          }
        }

        public var metadata: String? {
          get {
            return snapshot["metadata"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "metadata")
          }
        }

        public var createdBy: String {
          get {
            return snapshot["createdBy"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdBy")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String? {
          get {
            return snapshot["updatedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class GetNotificationPreferenceQuery: GraphQLQuery {
  public static let operationString =
    "query GetNotificationPreference($id: ID!) {\n  getNotificationPreference(id: $id) {\n    __typename\n    id\n    userId\n    generalBulletin\n    taskAlert\n    overtime\n    squadMessages\n    other\n    contactPhone\n    contactEmail\n    backupEmail\n    createdAt\n    updatedAt\n  }\n}"

  public var id: GraphQLID

  public init(id: GraphQLID) {
    self.id = id
  }

  public var variables: GraphQLMap? {
    return ["id": id]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("getNotificationPreference", arguments: ["id": GraphQLVariable("id")], type: .object(GetNotificationPreference.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(getNotificationPreference: GetNotificationPreference? = nil) {
      self.init(snapshot: ["__typename": "Query", "getNotificationPreference": getNotificationPreference.flatMap { $0.snapshot }])
    }

    public var getNotificationPreference: GetNotificationPreference? {
      get {
        return (snapshot["getNotificationPreference"] as? Snapshot).flatMap { GetNotificationPreference(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "getNotificationPreference")
      }
    }

    public struct GetNotificationPreference: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationPreference"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("userId", type: .nonNull(.scalar(String.self))),
        GraphQLField("generalBulletin", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("taskAlert", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("overtime", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("squadMessages", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("other", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("contactPhone", type: .scalar(String.self)),
        GraphQLField("contactEmail", type: .scalar(String.self)),
        GraphQLField("backupEmail", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, userId: String, generalBulletin: Bool, taskAlert: Bool, overtime: Bool, squadMessages: Bool, other: Bool, contactPhone: String? = nil, contactEmail: String? = nil, backupEmail: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationPreference", "id": id, "userId": userId, "generalBulletin": generalBulletin, "taskAlert": taskAlert, "overtime": overtime, "squadMessages": squadMessages, "other": other, "contactPhone": contactPhone, "contactEmail": contactEmail, "backupEmail": backupEmail, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var userId: String {
        get {
          return snapshot["userId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "userId")
        }
      }

      public var generalBulletin: Bool {
        get {
          return snapshot["generalBulletin"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "generalBulletin")
        }
      }

      public var taskAlert: Bool {
        get {
          return snapshot["taskAlert"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "taskAlert")
        }
      }

      public var overtime: Bool {
        get {
          return snapshot["overtime"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "overtime")
        }
      }

      public var squadMessages: Bool {
        get {
          return snapshot["squadMessages"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "squadMessages")
        }
      }

      public var other: Bool {
        get {
          return snapshot["other"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "other")
        }
      }

      public var contactPhone: String? {
        get {
          return snapshot["contactPhone"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "contactPhone")
        }
      }

      public var contactEmail: String? {
        get {
          return snapshot["contactEmail"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "contactEmail")
        }
      }

      public var backupEmail: String? {
        get {
          return snapshot["backupEmail"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "backupEmail")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class ListNotificationPreferencesQuery: GraphQLQuery {
  public static let operationString =
    "query ListNotificationPreferences($filter: ModelNotificationPreferenceFilterInput, $limit: Int, $nextToken: String) {\n  listNotificationPreferences(\n    filter: $filter\n    limit: $limit\n    nextToken: $nextToken\n  ) {\n    __typename\n    items {\n      __typename\n      id\n      userId\n      generalBulletin\n      taskAlert\n      overtime\n      squadMessages\n      other\n      contactPhone\n      contactEmail\n      backupEmail\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var filter: ModelNotificationPreferenceFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(filter: ModelNotificationPreferenceFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("listNotificationPreferences", arguments: ["filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(ListNotificationPreference.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(listNotificationPreferences: ListNotificationPreference? = nil) {
      self.init(snapshot: ["__typename": "Query", "listNotificationPreferences": listNotificationPreferences.flatMap { $0.snapshot }])
    }

    public var listNotificationPreferences: ListNotificationPreference? {
      get {
        return (snapshot["listNotificationPreferences"] as? Snapshot).flatMap { ListNotificationPreference(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "listNotificationPreferences")
      }
    }

    public struct ListNotificationPreference: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelNotificationPreferenceConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelNotificationPreferenceConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["NotificationPreference"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("userId", type: .nonNull(.scalar(String.self))),
          GraphQLField("generalBulletin", type: .nonNull(.scalar(Bool.self))),
          GraphQLField("taskAlert", type: .nonNull(.scalar(Bool.self))),
          GraphQLField("overtime", type: .nonNull(.scalar(Bool.self))),
          GraphQLField("squadMessages", type: .nonNull(.scalar(Bool.self))),
          GraphQLField("other", type: .nonNull(.scalar(Bool.self))),
          GraphQLField("contactPhone", type: .scalar(String.self)),
          GraphQLField("contactEmail", type: .scalar(String.self)),
          GraphQLField("backupEmail", type: .scalar(String.self)),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, userId: String, generalBulletin: Bool, taskAlert: Bool, overtime: Bool, squadMessages: Bool, other: Bool, contactPhone: String? = nil, contactEmail: String? = nil, backupEmail: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
          self.init(snapshot: ["__typename": "NotificationPreference", "id": id, "userId": userId, "generalBulletin": generalBulletin, "taskAlert": taskAlert, "overtime": overtime, "squadMessages": squadMessages, "other": other, "contactPhone": contactPhone, "contactEmail": contactEmail, "backupEmail": backupEmail, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var userId: String {
          get {
            return snapshot["userId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "userId")
          }
        }

        public var generalBulletin: Bool {
          get {
            return snapshot["generalBulletin"]! as! Bool
          }
          set {
            snapshot.updateValue(newValue, forKey: "generalBulletin")
          }
        }

        public var taskAlert: Bool {
          get {
            return snapshot["taskAlert"]! as! Bool
          }
          set {
            snapshot.updateValue(newValue, forKey: "taskAlert")
          }
        }

        public var overtime: Bool {
          get {
            return snapshot["overtime"]! as! Bool
          }
          set {
            snapshot.updateValue(newValue, forKey: "overtime")
          }
        }

        public var squadMessages: Bool {
          get {
            return snapshot["squadMessages"]! as! Bool
          }
          set {
            snapshot.updateValue(newValue, forKey: "squadMessages")
          }
        }

        public var other: Bool {
          get {
            return snapshot["other"]! as! Bool
          }
          set {
            snapshot.updateValue(newValue, forKey: "other")
          }
        }

        public var contactPhone: String? {
          get {
            return snapshot["contactPhone"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "contactPhone")
          }
        }

        public var contactEmail: String? {
          get {
            return snapshot["contactEmail"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "contactEmail")
          }
        }

        public var backupEmail: String? {
          get {
            return snapshot["backupEmail"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "backupEmail")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String? {
          get {
            return snapshot["updatedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class NotificationPreferencesByUserQuery: GraphQLQuery {
  public static let operationString =
    "query NotificationPreferencesByUser($userId: String!, $sortDirection: ModelSortDirection, $filter: ModelNotificationPreferenceFilterInput, $limit: Int, $nextToken: String) {\n  notificationPreferencesByUser(\n    userId: $userId\n    sortDirection: $sortDirection\n    filter: $filter\n    limit: $limit\n    nextToken: $nextToken\n  ) {\n    __typename\n    items {\n      __typename\n      id\n      userId\n      generalBulletin\n      taskAlert\n      overtime\n      squadMessages\n      other\n      contactPhone\n      contactEmail\n      backupEmail\n      createdAt\n      updatedAt\n    }\n    nextToken\n  }\n}"

  public var userId: String
  public var sortDirection: ModelSortDirection?
  public var filter: ModelNotificationPreferenceFilterInput?
  public var limit: Int?
  public var nextToken: String?

  public init(userId: String, sortDirection: ModelSortDirection? = nil, filter: ModelNotificationPreferenceFilterInput? = nil, limit: Int? = nil, nextToken: String? = nil) {
    self.userId = userId
    self.sortDirection = sortDirection
    self.filter = filter
    self.limit = limit
    self.nextToken = nextToken
  }

  public var variables: GraphQLMap? {
    return ["userId": userId, "sortDirection": sortDirection, "filter": filter, "limit": limit, "nextToken": nextToken]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Query"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("notificationPreferencesByUser", arguments: ["userId": GraphQLVariable("userId"), "sortDirection": GraphQLVariable("sortDirection"), "filter": GraphQLVariable("filter"), "limit": GraphQLVariable("limit"), "nextToken": GraphQLVariable("nextToken")], type: .object(NotificationPreferencesByUser.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(notificationPreferencesByUser: NotificationPreferencesByUser? = nil) {
      self.init(snapshot: ["__typename": "Query", "notificationPreferencesByUser": notificationPreferencesByUser.flatMap { $0.snapshot }])
    }

    public var notificationPreferencesByUser: NotificationPreferencesByUser? {
      get {
        return (snapshot["notificationPreferencesByUser"] as? Snapshot).flatMap { NotificationPreferencesByUser(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "notificationPreferencesByUser")
      }
    }

    public struct NotificationPreferencesByUser: GraphQLSelectionSet {
      public static let possibleTypes = ["ModelNotificationPreferenceConnection"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("items", type: .nonNull(.list(.object(Item.selections)))),
        GraphQLField("nextToken", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(items: [Item?], nextToken: String? = nil) {
        self.init(snapshot: ["__typename": "ModelNotificationPreferenceConnection", "items": items.map { $0.flatMap { $0.snapshot } }, "nextToken": nextToken])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var items: [Item?] {
        get {
          return (snapshot["items"] as! [Snapshot?]).map { $0.flatMap { Item(snapshot: $0) } }
        }
        set {
          snapshot.updateValue(newValue.map { $0.flatMap { $0.snapshot } }, forKey: "items")
        }
      }

      public var nextToken: String? {
        get {
          return snapshot["nextToken"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "nextToken")
        }
      }

      public struct Item: GraphQLSelectionSet {
        public static let possibleTypes = ["NotificationPreference"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
          GraphQLField("userId", type: .nonNull(.scalar(String.self))),
          GraphQLField("generalBulletin", type: .nonNull(.scalar(Bool.self))),
          GraphQLField("taskAlert", type: .nonNull(.scalar(Bool.self))),
          GraphQLField("overtime", type: .nonNull(.scalar(Bool.self))),
          GraphQLField("squadMessages", type: .nonNull(.scalar(Bool.self))),
          GraphQLField("other", type: .nonNull(.scalar(Bool.self))),
          GraphQLField("contactPhone", type: .scalar(String.self)),
          GraphQLField("contactEmail", type: .scalar(String.self)),
          GraphQLField("backupEmail", type: .scalar(String.self)),
          GraphQLField("createdAt", type: .scalar(String.self)),
          GraphQLField("updatedAt", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(id: GraphQLID, userId: String, generalBulletin: Bool, taskAlert: Bool, overtime: Bool, squadMessages: Bool, other: Bool, contactPhone: String? = nil, contactEmail: String? = nil, backupEmail: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
          self.init(snapshot: ["__typename": "NotificationPreference", "id": id, "userId": userId, "generalBulletin": generalBulletin, "taskAlert": taskAlert, "overtime": overtime, "squadMessages": squadMessages, "other": other, "contactPhone": contactPhone, "contactEmail": contactEmail, "backupEmail": backupEmail, "createdAt": createdAt, "updatedAt": updatedAt])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }

        public var userId: String {
          get {
            return snapshot["userId"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "userId")
          }
        }

        public var generalBulletin: Bool {
          get {
            return snapshot["generalBulletin"]! as! Bool
          }
          set {
            snapshot.updateValue(newValue, forKey: "generalBulletin")
          }
        }

        public var taskAlert: Bool {
          get {
            return snapshot["taskAlert"]! as! Bool
          }
          set {
            snapshot.updateValue(newValue, forKey: "taskAlert")
          }
        }

        public var overtime: Bool {
          get {
            return snapshot["overtime"]! as! Bool
          }
          set {
            snapshot.updateValue(newValue, forKey: "overtime")
          }
        }

        public var squadMessages: Bool {
          get {
            return snapshot["squadMessages"]! as! Bool
          }
          set {
            snapshot.updateValue(newValue, forKey: "squadMessages")
          }
        }

        public var other: Bool {
          get {
            return snapshot["other"]! as! Bool
          }
          set {
            snapshot.updateValue(newValue, forKey: "other")
          }
        }

        public var contactPhone: String? {
          get {
            return snapshot["contactPhone"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "contactPhone")
          }
        }

        public var contactEmail: String? {
          get {
            return snapshot["contactEmail"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "contactEmail")
          }
        }

        public var backupEmail: String? {
          get {
            return snapshot["backupEmail"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "backupEmail")
          }
        }

        public var createdAt: String? {
          get {
            return snapshot["createdAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "createdAt")
          }
        }

        public var updatedAt: String? {
          get {
            return snapshot["updatedAt"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "updatedAt")
          }
        }
      }
    }
  }
}

public final class OnCreateRosterEntrySubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnCreateRosterEntry($filter: ModelSubscriptionRosterEntryFilterInput, $badgeNumber: String) {\n  onCreateRosterEntry(filter: $filter, badgeNumber: $badgeNumber) {\n    __typename\n    id\n    orgId\n    badgeNumber\n    shift\n    startsAt\n    endsAt\n    notes\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionRosterEntryFilterInput?
  public var badgeNumber: String?

  public init(filter: ModelSubscriptionRosterEntryFilterInput? = nil, badgeNumber: String? = nil) {
    self.filter = filter
    self.badgeNumber = badgeNumber
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "badgeNumber": badgeNumber]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onCreateRosterEntry", arguments: ["filter": GraphQLVariable("filter"), "badgeNumber": GraphQLVariable("badgeNumber")], type: .object(OnCreateRosterEntry.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onCreateRosterEntry: OnCreateRosterEntry? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onCreateRosterEntry": onCreateRosterEntry.flatMap { $0.snapshot }])
    }

    public var onCreateRosterEntry: OnCreateRosterEntry? {
      get {
        return (snapshot["onCreateRosterEntry"] as? Snapshot).flatMap { OnCreateRosterEntry(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onCreateRosterEntry")
      }
    }

    public struct OnCreateRosterEntry: GraphQLSelectionSet {
      public static let possibleTypes = ["RosterEntry"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("badgeNumber", type: .nonNull(.scalar(String.self))),
        GraphQLField("shift", type: .scalar(String.self)),
        GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("notes", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, badgeNumber: String, shift: String? = nil, startsAt: String, endsAt: String, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "RosterEntry", "id": id, "orgId": orgId, "badgeNumber": badgeNumber, "shift": shift, "startsAt": startsAt, "endsAt": endsAt, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var badgeNumber: String {
        get {
          return snapshot["badgeNumber"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "badgeNumber")
        }
      }

      public var shift: String? {
        get {
          return snapshot["shift"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "shift")
        }
      }

      public var startsAt: String {
        get {
          return snapshot["startsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "startsAt")
        }
      }

      public var endsAt: String {
        get {
          return snapshot["endsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "endsAt")
        }
      }

      public var notes: String? {
        get {
          return snapshot["notes"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "notes")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnUpdateRosterEntrySubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnUpdateRosterEntry($filter: ModelSubscriptionRosterEntryFilterInput, $badgeNumber: String) {\n  onUpdateRosterEntry(filter: $filter, badgeNumber: $badgeNumber) {\n    __typename\n    id\n    orgId\n    badgeNumber\n    shift\n    startsAt\n    endsAt\n    notes\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionRosterEntryFilterInput?
  public var badgeNumber: String?

  public init(filter: ModelSubscriptionRosterEntryFilterInput? = nil, badgeNumber: String? = nil) {
    self.filter = filter
    self.badgeNumber = badgeNumber
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "badgeNumber": badgeNumber]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onUpdateRosterEntry", arguments: ["filter": GraphQLVariable("filter"), "badgeNumber": GraphQLVariable("badgeNumber")], type: .object(OnUpdateRosterEntry.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onUpdateRosterEntry: OnUpdateRosterEntry? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onUpdateRosterEntry": onUpdateRosterEntry.flatMap { $0.snapshot }])
    }

    public var onUpdateRosterEntry: OnUpdateRosterEntry? {
      get {
        return (snapshot["onUpdateRosterEntry"] as? Snapshot).flatMap { OnUpdateRosterEntry(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onUpdateRosterEntry")
      }
    }

    public struct OnUpdateRosterEntry: GraphQLSelectionSet {
      public static let possibleTypes = ["RosterEntry"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("badgeNumber", type: .nonNull(.scalar(String.self))),
        GraphQLField("shift", type: .scalar(String.self)),
        GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("notes", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, badgeNumber: String, shift: String? = nil, startsAt: String, endsAt: String, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "RosterEntry", "id": id, "orgId": orgId, "badgeNumber": badgeNumber, "shift": shift, "startsAt": startsAt, "endsAt": endsAt, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var badgeNumber: String {
        get {
          return snapshot["badgeNumber"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "badgeNumber")
        }
      }

      public var shift: String? {
        get {
          return snapshot["shift"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "shift")
        }
      }

      public var startsAt: String {
        get {
          return snapshot["startsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "startsAt")
        }
      }

      public var endsAt: String {
        get {
          return snapshot["endsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "endsAt")
        }
      }

      public var notes: String? {
        get {
          return snapshot["notes"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "notes")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnDeleteRosterEntrySubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnDeleteRosterEntry($filter: ModelSubscriptionRosterEntryFilterInput, $badgeNumber: String) {\n  onDeleteRosterEntry(filter: $filter, badgeNumber: $badgeNumber) {\n    __typename\n    id\n    orgId\n    badgeNumber\n    shift\n    startsAt\n    endsAt\n    notes\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionRosterEntryFilterInput?
  public var badgeNumber: String?

  public init(filter: ModelSubscriptionRosterEntryFilterInput? = nil, badgeNumber: String? = nil) {
    self.filter = filter
    self.badgeNumber = badgeNumber
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "badgeNumber": badgeNumber]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onDeleteRosterEntry", arguments: ["filter": GraphQLVariable("filter"), "badgeNumber": GraphQLVariable("badgeNumber")], type: .object(OnDeleteRosterEntry.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onDeleteRosterEntry: OnDeleteRosterEntry? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onDeleteRosterEntry": onDeleteRosterEntry.flatMap { $0.snapshot }])
    }

    public var onDeleteRosterEntry: OnDeleteRosterEntry? {
      get {
        return (snapshot["onDeleteRosterEntry"] as? Snapshot).flatMap { OnDeleteRosterEntry(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onDeleteRosterEntry")
      }
    }

    public struct OnDeleteRosterEntry: GraphQLSelectionSet {
      public static let possibleTypes = ["RosterEntry"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("badgeNumber", type: .nonNull(.scalar(String.self))),
        GraphQLField("shift", type: .scalar(String.self)),
        GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("notes", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, badgeNumber: String, shift: String? = nil, startsAt: String, endsAt: String, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "RosterEntry", "id": id, "orgId": orgId, "badgeNumber": badgeNumber, "shift": shift, "startsAt": startsAt, "endsAt": endsAt, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var badgeNumber: String {
        get {
          return snapshot["badgeNumber"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "badgeNumber")
        }
      }

      public var shift: String? {
        get {
          return snapshot["shift"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "shift")
        }
      }

      public var startsAt: String {
        get {
          return snapshot["startsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "startsAt")
        }
      }

      public var endsAt: String {
        get {
          return snapshot["endsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "endsAt")
        }
      }

      public var notes: String? {
        get {
          return snapshot["notes"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "notes")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnCreateVehicleSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnCreateVehicle($filter: ModelSubscriptionVehicleFilterInput) {\n  onCreateVehicle(filter: $filter) {\n    __typename\n    id\n    orgId\n    callsign\n    make\n    model\n    plate\n    inService\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionVehicleFilterInput?

  public init(filter: ModelSubscriptionVehicleFilterInput? = nil) {
    self.filter = filter
  }

  public var variables: GraphQLMap? {
    return ["filter": filter]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onCreateVehicle", arguments: ["filter": GraphQLVariable("filter")], type: .object(OnCreateVehicle.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onCreateVehicle: OnCreateVehicle? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onCreateVehicle": onCreateVehicle.flatMap { $0.snapshot }])
    }

    public var onCreateVehicle: OnCreateVehicle? {
      get {
        return (snapshot["onCreateVehicle"] as? Snapshot).flatMap { OnCreateVehicle(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onCreateVehicle")
      }
    }

    public struct OnCreateVehicle: GraphQLSelectionSet {
      public static let possibleTypes = ["Vehicle"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("callsign", type: .nonNull(.scalar(String.self))),
        GraphQLField("make", type: .scalar(String.self)),
        GraphQLField("model", type: .scalar(String.self)),
        GraphQLField("plate", type: .scalar(String.self)),
        GraphQLField("inService", type: .scalar(Bool.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, callsign: String, make: String? = nil, model: String? = nil, plate: String? = nil, inService: Bool? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "Vehicle", "id": id, "orgId": orgId, "callsign": callsign, "make": make, "model": model, "plate": plate, "inService": inService, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var callsign: String {
        get {
          return snapshot["callsign"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "callsign")
        }
      }

      public var make: String? {
        get {
          return snapshot["make"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "make")
        }
      }

      public var model: String? {
        get {
          return snapshot["model"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "model")
        }
      }

      public var plate: String? {
        get {
          return snapshot["plate"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "plate")
        }
      }

      public var inService: Bool? {
        get {
          return snapshot["inService"] as? Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "inService")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnUpdateVehicleSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnUpdateVehicle($filter: ModelSubscriptionVehicleFilterInput) {\n  onUpdateVehicle(filter: $filter) {\n    __typename\n    id\n    orgId\n    callsign\n    make\n    model\n    plate\n    inService\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionVehicleFilterInput?

  public init(filter: ModelSubscriptionVehicleFilterInput? = nil) {
    self.filter = filter
  }

  public var variables: GraphQLMap? {
    return ["filter": filter]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onUpdateVehicle", arguments: ["filter": GraphQLVariable("filter")], type: .object(OnUpdateVehicle.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onUpdateVehicle: OnUpdateVehicle? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onUpdateVehicle": onUpdateVehicle.flatMap { $0.snapshot }])
    }

    public var onUpdateVehicle: OnUpdateVehicle? {
      get {
        return (snapshot["onUpdateVehicle"] as? Snapshot).flatMap { OnUpdateVehicle(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onUpdateVehicle")
      }
    }

    public struct OnUpdateVehicle: GraphQLSelectionSet {
      public static let possibleTypes = ["Vehicle"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("callsign", type: .nonNull(.scalar(String.self))),
        GraphQLField("make", type: .scalar(String.self)),
        GraphQLField("model", type: .scalar(String.self)),
        GraphQLField("plate", type: .scalar(String.self)),
        GraphQLField("inService", type: .scalar(Bool.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, callsign: String, make: String? = nil, model: String? = nil, plate: String? = nil, inService: Bool? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "Vehicle", "id": id, "orgId": orgId, "callsign": callsign, "make": make, "model": model, "plate": plate, "inService": inService, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var callsign: String {
        get {
          return snapshot["callsign"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "callsign")
        }
      }

      public var make: String? {
        get {
          return snapshot["make"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "make")
        }
      }

      public var model: String? {
        get {
          return snapshot["model"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "model")
        }
      }

      public var plate: String? {
        get {
          return snapshot["plate"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "plate")
        }
      }

      public var inService: Bool? {
        get {
          return snapshot["inService"] as? Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "inService")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnDeleteVehicleSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnDeleteVehicle($filter: ModelSubscriptionVehicleFilterInput) {\n  onDeleteVehicle(filter: $filter) {\n    __typename\n    id\n    orgId\n    callsign\n    make\n    model\n    plate\n    inService\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionVehicleFilterInput?

  public init(filter: ModelSubscriptionVehicleFilterInput? = nil) {
    self.filter = filter
  }

  public var variables: GraphQLMap? {
    return ["filter": filter]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onDeleteVehicle", arguments: ["filter": GraphQLVariable("filter")], type: .object(OnDeleteVehicle.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onDeleteVehicle: OnDeleteVehicle? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onDeleteVehicle": onDeleteVehicle.flatMap { $0.snapshot }])
    }

    public var onDeleteVehicle: OnDeleteVehicle? {
      get {
        return (snapshot["onDeleteVehicle"] as? Snapshot).flatMap { OnDeleteVehicle(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onDeleteVehicle")
      }
    }

    public struct OnDeleteVehicle: GraphQLSelectionSet {
      public static let possibleTypes = ["Vehicle"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("callsign", type: .nonNull(.scalar(String.self))),
        GraphQLField("make", type: .scalar(String.self)),
        GraphQLField("model", type: .scalar(String.self)),
        GraphQLField("plate", type: .scalar(String.self)),
        GraphQLField("inService", type: .scalar(Bool.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, callsign: String, make: String? = nil, model: String? = nil, plate: String? = nil, inService: Bool? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "Vehicle", "id": id, "orgId": orgId, "callsign": callsign, "make": make, "model": model, "plate": plate, "inService": inService, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var callsign: String {
        get {
          return snapshot["callsign"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "callsign")
        }
      }

      public var make: String? {
        get {
          return snapshot["make"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "make")
        }
      }

      public var model: String? {
        get {
          return snapshot["model"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "model")
        }
      }

      public var plate: String? {
        get {
          return snapshot["plate"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "plate")
        }
      }

      public var inService: Bool? {
        get {
          return snapshot["inService"] as? Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "inService")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnCreateCalendarEventSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnCreateCalendarEvent($filter: ModelSubscriptionCalendarEventFilterInput, $ownerId: String) {\n  onCreateCalendarEvent(filter: $filter, ownerId: $ownerId) {\n    __typename\n    id\n    orgId\n    ownerId\n    title\n    category\n    color\n    notes\n    startsAt\n    endsAt\n    reminderMinutesBefore\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionCalendarEventFilterInput?
  public var ownerId: String?

  public init(filter: ModelSubscriptionCalendarEventFilterInput? = nil, ownerId: String? = nil) {
    self.filter = filter
    self.ownerId = ownerId
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "ownerId": ownerId]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onCreateCalendarEvent", arguments: ["filter": GraphQLVariable("filter"), "ownerId": GraphQLVariable("ownerId")], type: .object(OnCreateCalendarEvent.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onCreateCalendarEvent: OnCreateCalendarEvent? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onCreateCalendarEvent": onCreateCalendarEvent.flatMap { $0.snapshot }])
    }

    public var onCreateCalendarEvent: OnCreateCalendarEvent? {
      get {
        return (snapshot["onCreateCalendarEvent"] as? Snapshot).flatMap { OnCreateCalendarEvent(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onCreateCalendarEvent")
      }
    }

    public struct OnCreateCalendarEvent: GraphQLSelectionSet {
      public static let possibleTypes = ["CalendarEvent"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("ownerId", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("category", type: .nonNull(.scalar(String.self))),
        GraphQLField("color", type: .nonNull(.scalar(String.self))),
        GraphQLField("notes", type: .scalar(String.self)),
        GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("reminderMinutesBefore", type: .scalar(Int.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, ownerId: String, title: String, category: String, color: String, notes: String? = nil, startsAt: String, endsAt: String, reminderMinutesBefore: Int? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "CalendarEvent", "id": id, "orgId": orgId, "ownerId": ownerId, "title": title, "category": category, "color": color, "notes": notes, "startsAt": startsAt, "endsAt": endsAt, "reminderMinutesBefore": reminderMinutesBefore, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var ownerId: String {
        get {
          return snapshot["ownerId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "ownerId")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var category: String {
        get {
          return snapshot["category"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "category")
        }
      }

      public var color: String {
        get {
          return snapshot["color"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "color")
        }
      }

      public var notes: String? {
        get {
          return snapshot["notes"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "notes")
        }
      }

      public var startsAt: String {
        get {
          return snapshot["startsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "startsAt")
        }
      }

      public var endsAt: String {
        get {
          return snapshot["endsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "endsAt")
        }
      }

      public var reminderMinutesBefore: Int? {
        get {
          return snapshot["reminderMinutesBefore"] as? Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "reminderMinutesBefore")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnUpdateCalendarEventSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnUpdateCalendarEvent($filter: ModelSubscriptionCalendarEventFilterInput, $ownerId: String) {\n  onUpdateCalendarEvent(filter: $filter, ownerId: $ownerId) {\n    __typename\n    id\n    orgId\n    ownerId\n    title\n    category\n    color\n    notes\n    startsAt\n    endsAt\n    reminderMinutesBefore\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionCalendarEventFilterInput?
  public var ownerId: String?

  public init(filter: ModelSubscriptionCalendarEventFilterInput? = nil, ownerId: String? = nil) {
    self.filter = filter
    self.ownerId = ownerId
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "ownerId": ownerId]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onUpdateCalendarEvent", arguments: ["filter": GraphQLVariable("filter"), "ownerId": GraphQLVariable("ownerId")], type: .object(OnUpdateCalendarEvent.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onUpdateCalendarEvent: OnUpdateCalendarEvent? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onUpdateCalendarEvent": onUpdateCalendarEvent.flatMap { $0.snapshot }])
    }

    public var onUpdateCalendarEvent: OnUpdateCalendarEvent? {
      get {
        return (snapshot["onUpdateCalendarEvent"] as? Snapshot).flatMap { OnUpdateCalendarEvent(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onUpdateCalendarEvent")
      }
    }

    public struct OnUpdateCalendarEvent: GraphQLSelectionSet {
      public static let possibleTypes = ["CalendarEvent"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("ownerId", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("category", type: .nonNull(.scalar(String.self))),
        GraphQLField("color", type: .nonNull(.scalar(String.self))),
        GraphQLField("notes", type: .scalar(String.self)),
        GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("reminderMinutesBefore", type: .scalar(Int.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, ownerId: String, title: String, category: String, color: String, notes: String? = nil, startsAt: String, endsAt: String, reminderMinutesBefore: Int? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "CalendarEvent", "id": id, "orgId": orgId, "ownerId": ownerId, "title": title, "category": category, "color": color, "notes": notes, "startsAt": startsAt, "endsAt": endsAt, "reminderMinutesBefore": reminderMinutesBefore, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var ownerId: String {
        get {
          return snapshot["ownerId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "ownerId")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var category: String {
        get {
          return snapshot["category"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "category")
        }
      }

      public var color: String {
        get {
          return snapshot["color"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "color")
        }
      }

      public var notes: String? {
        get {
          return snapshot["notes"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "notes")
        }
      }

      public var startsAt: String {
        get {
          return snapshot["startsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "startsAt")
        }
      }

      public var endsAt: String {
        get {
          return snapshot["endsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "endsAt")
        }
      }

      public var reminderMinutesBefore: Int? {
        get {
          return snapshot["reminderMinutesBefore"] as? Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "reminderMinutesBefore")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnDeleteCalendarEventSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnDeleteCalendarEvent($filter: ModelSubscriptionCalendarEventFilterInput, $ownerId: String) {\n  onDeleteCalendarEvent(filter: $filter, ownerId: $ownerId) {\n    __typename\n    id\n    orgId\n    ownerId\n    title\n    category\n    color\n    notes\n    startsAt\n    endsAt\n    reminderMinutesBefore\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionCalendarEventFilterInput?
  public var ownerId: String?

  public init(filter: ModelSubscriptionCalendarEventFilterInput? = nil, ownerId: String? = nil) {
    self.filter = filter
    self.ownerId = ownerId
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "ownerId": ownerId]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onDeleteCalendarEvent", arguments: ["filter": GraphQLVariable("filter"), "ownerId": GraphQLVariable("ownerId")], type: .object(OnDeleteCalendarEvent.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onDeleteCalendarEvent: OnDeleteCalendarEvent? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onDeleteCalendarEvent": onDeleteCalendarEvent.flatMap { $0.snapshot }])
    }

    public var onDeleteCalendarEvent: OnDeleteCalendarEvent? {
      get {
        return (snapshot["onDeleteCalendarEvent"] as? Snapshot).flatMap { OnDeleteCalendarEvent(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onDeleteCalendarEvent")
      }
    }

    public struct OnDeleteCalendarEvent: GraphQLSelectionSet {
      public static let possibleTypes = ["CalendarEvent"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("ownerId", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("category", type: .nonNull(.scalar(String.self))),
        GraphQLField("color", type: .nonNull(.scalar(String.self))),
        GraphQLField("notes", type: .scalar(String.self)),
        GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("reminderMinutesBefore", type: .scalar(Int.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, ownerId: String, title: String, category: String, color: String, notes: String? = nil, startsAt: String, endsAt: String, reminderMinutesBefore: Int? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "CalendarEvent", "id": id, "orgId": orgId, "ownerId": ownerId, "title": title, "category": category, "color": color, "notes": notes, "startsAt": startsAt, "endsAt": endsAt, "reminderMinutesBefore": reminderMinutesBefore, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var ownerId: String {
        get {
          return snapshot["ownerId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "ownerId")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var category: String {
        get {
          return snapshot["category"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "category")
        }
      }

      public var color: String {
        get {
          return snapshot["color"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "color")
        }
      }

      public var notes: String? {
        get {
          return snapshot["notes"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "notes")
        }
      }

      public var startsAt: String {
        get {
          return snapshot["startsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "startsAt")
        }
      }

      public var endsAt: String {
        get {
          return snapshot["endsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "endsAt")
        }
      }

      public var reminderMinutesBefore: Int? {
        get {
          return snapshot["reminderMinutesBefore"] as? Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "reminderMinutesBefore")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnCreateOfficerAssignmentSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnCreateOfficerAssignment($filter: ModelSubscriptionOfficerAssignmentFilterInput, $badgeNumber: String) {\n  onCreateOfficerAssignment(filter: $filter, badgeNumber: $badgeNumber) {\n    __typename\n    id\n    orgId\n    badgeNumber\n    title\n    detail\n    location\n    notes\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionOfficerAssignmentFilterInput?
  public var badgeNumber: String?

  public init(filter: ModelSubscriptionOfficerAssignmentFilterInput? = nil, badgeNumber: String? = nil) {
    self.filter = filter
    self.badgeNumber = badgeNumber
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "badgeNumber": badgeNumber]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onCreateOfficerAssignment", arguments: ["filter": GraphQLVariable("filter"), "badgeNumber": GraphQLVariable("badgeNumber")], type: .object(OnCreateOfficerAssignment.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onCreateOfficerAssignment: OnCreateOfficerAssignment? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onCreateOfficerAssignment": onCreateOfficerAssignment.flatMap { $0.snapshot }])
    }

    public var onCreateOfficerAssignment: OnCreateOfficerAssignment? {
      get {
        return (snapshot["onCreateOfficerAssignment"] as? Snapshot).flatMap { OnCreateOfficerAssignment(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onCreateOfficerAssignment")
      }
    }

    public struct OnCreateOfficerAssignment: GraphQLSelectionSet {
      public static let possibleTypes = ["OfficerAssignment"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("badgeNumber", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("detail", type: .scalar(String.self)),
        GraphQLField("location", type: .scalar(String.self)),
        GraphQLField("notes", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, badgeNumber: String, title: String, detail: String? = nil, location: String? = nil, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "OfficerAssignment", "id": id, "orgId": orgId, "badgeNumber": badgeNumber, "title": title, "detail": detail, "location": location, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var badgeNumber: String {
        get {
          return snapshot["badgeNumber"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "badgeNumber")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var detail: String? {
        get {
          return snapshot["detail"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "detail")
        }
      }

      public var location: String? {
        get {
          return snapshot["location"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "location")
        }
      }

      public var notes: String? {
        get {
          return snapshot["notes"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "notes")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnUpdateOfficerAssignmentSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnUpdateOfficerAssignment($filter: ModelSubscriptionOfficerAssignmentFilterInput, $badgeNumber: String) {\n  onUpdateOfficerAssignment(filter: $filter, badgeNumber: $badgeNumber) {\n    __typename\n    id\n    orgId\n    badgeNumber\n    title\n    detail\n    location\n    notes\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionOfficerAssignmentFilterInput?
  public var badgeNumber: String?

  public init(filter: ModelSubscriptionOfficerAssignmentFilterInput? = nil, badgeNumber: String? = nil) {
    self.filter = filter
    self.badgeNumber = badgeNumber
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "badgeNumber": badgeNumber]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onUpdateOfficerAssignment", arguments: ["filter": GraphQLVariable("filter"), "badgeNumber": GraphQLVariable("badgeNumber")], type: .object(OnUpdateOfficerAssignment.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onUpdateOfficerAssignment: OnUpdateOfficerAssignment? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onUpdateOfficerAssignment": onUpdateOfficerAssignment.flatMap { $0.snapshot }])
    }

    public var onUpdateOfficerAssignment: OnUpdateOfficerAssignment? {
      get {
        return (snapshot["onUpdateOfficerAssignment"] as? Snapshot).flatMap { OnUpdateOfficerAssignment(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onUpdateOfficerAssignment")
      }
    }

    public struct OnUpdateOfficerAssignment: GraphQLSelectionSet {
      public static let possibleTypes = ["OfficerAssignment"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("badgeNumber", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("detail", type: .scalar(String.self)),
        GraphQLField("location", type: .scalar(String.self)),
        GraphQLField("notes", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, badgeNumber: String, title: String, detail: String? = nil, location: String? = nil, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "OfficerAssignment", "id": id, "orgId": orgId, "badgeNumber": badgeNumber, "title": title, "detail": detail, "location": location, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var badgeNumber: String {
        get {
          return snapshot["badgeNumber"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "badgeNumber")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var detail: String? {
        get {
          return snapshot["detail"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "detail")
        }
      }

      public var location: String? {
        get {
          return snapshot["location"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "location")
        }
      }

      public var notes: String? {
        get {
          return snapshot["notes"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "notes")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnDeleteOfficerAssignmentSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnDeleteOfficerAssignment($filter: ModelSubscriptionOfficerAssignmentFilterInput, $badgeNumber: String) {\n  onDeleteOfficerAssignment(filter: $filter, badgeNumber: $badgeNumber) {\n    __typename\n    id\n    orgId\n    badgeNumber\n    title\n    detail\n    location\n    notes\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionOfficerAssignmentFilterInput?
  public var badgeNumber: String?

  public init(filter: ModelSubscriptionOfficerAssignmentFilterInput? = nil, badgeNumber: String? = nil) {
    self.filter = filter
    self.badgeNumber = badgeNumber
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "badgeNumber": badgeNumber]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onDeleteOfficerAssignment", arguments: ["filter": GraphQLVariable("filter"), "badgeNumber": GraphQLVariable("badgeNumber")], type: .object(OnDeleteOfficerAssignment.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onDeleteOfficerAssignment: OnDeleteOfficerAssignment? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onDeleteOfficerAssignment": onDeleteOfficerAssignment.flatMap { $0.snapshot }])
    }

    public var onDeleteOfficerAssignment: OnDeleteOfficerAssignment? {
      get {
        return (snapshot["onDeleteOfficerAssignment"] as? Snapshot).flatMap { OnDeleteOfficerAssignment(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onDeleteOfficerAssignment")
      }
    }

    public struct OnDeleteOfficerAssignment: GraphQLSelectionSet {
      public static let possibleTypes = ["OfficerAssignment"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("badgeNumber", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("detail", type: .scalar(String.self)),
        GraphQLField("location", type: .scalar(String.self)),
        GraphQLField("notes", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, badgeNumber: String, title: String, detail: String? = nil, location: String? = nil, notes: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "OfficerAssignment", "id": id, "orgId": orgId, "badgeNumber": badgeNumber, "title": title, "detail": detail, "location": location, "notes": notes, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var badgeNumber: String {
        get {
          return snapshot["badgeNumber"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "badgeNumber")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var detail: String? {
        get {
          return snapshot["detail"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "detail")
        }
      }

      public var location: String? {
        get {
          return snapshot["location"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "location")
        }
      }

      public var notes: String? {
        get {
          return snapshot["notes"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "notes")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnCreateOvertimePostingSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnCreateOvertimePosting($filter: ModelSubscriptionOvertimePostingFilterInput, $createdBy: String) {\n  onCreateOvertimePosting(filter: $filter, createdBy: $createdBy) {\n    __typename\n    id\n    orgId\n    title\n    location\n    scenario\n    startsAt\n    endsAt\n    slots\n    policySnapshot\n    selectionPolicy\n    needsEscalation\n    state\n    createdBy\n    invites {\n      __typename\n      nextToken\n    }\n    auditTrail {\n      __typename\n      nextToken\n    }\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionOvertimePostingFilterInput?
  public var createdBy: String?

  public init(filter: ModelSubscriptionOvertimePostingFilterInput? = nil, createdBy: String? = nil) {
    self.filter = filter
    self.createdBy = createdBy
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "createdBy": createdBy]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onCreateOvertimePosting", arguments: ["filter": GraphQLVariable("filter"), "createdBy": GraphQLVariable("createdBy")], type: .object(OnCreateOvertimePosting.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onCreateOvertimePosting: OnCreateOvertimePosting? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onCreateOvertimePosting": onCreateOvertimePosting.flatMap { $0.snapshot }])
    }

    public var onCreateOvertimePosting: OnCreateOvertimePosting? {
      get {
        return (snapshot["onCreateOvertimePosting"] as? Snapshot).flatMap { OnCreateOvertimePosting(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onCreateOvertimePosting")
      }
    }

    public struct OnCreateOvertimePosting: GraphQLSelectionSet {
      public static let possibleTypes = ["OvertimePosting"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("location", type: .scalar(String.self)),
        GraphQLField("scenario", type: .nonNull(.scalar(OvertimeScenario.self))),
        GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("slots", type: .nonNull(.scalar(Int.self))),
        GraphQLField("policySnapshot", type: .nonNull(.scalar(String.self))),
        GraphQLField("selectionPolicy", type: .scalar(OvertimeSelectionPolicy.self)),
        GraphQLField("needsEscalation", type: .scalar(Bool.self)),
        GraphQLField("state", type: .nonNull(.scalar(OvertimePostingState.self))),
        GraphQLField("createdBy", type: .nonNull(.scalar(String.self))),
        GraphQLField("invites", type: .object(Invite.selections)),
        GraphQLField("auditTrail", type: .object(AuditTrail.selections)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, title: String, location: String? = nil, scenario: OvertimeScenario, startsAt: String, endsAt: String, slots: Int, policySnapshot: String, selectionPolicy: OvertimeSelectionPolicy? = nil, needsEscalation: Bool? = nil, state: OvertimePostingState, createdBy: String, invites: Invite? = nil, auditTrail: AuditTrail? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "OvertimePosting", "id": id, "orgId": orgId, "title": title, "location": location, "scenario": scenario, "startsAt": startsAt, "endsAt": endsAt, "slots": slots, "policySnapshot": policySnapshot, "selectionPolicy": selectionPolicy, "needsEscalation": needsEscalation, "state": state, "createdBy": createdBy, "invites": invites.flatMap { $0.snapshot }, "auditTrail": auditTrail.flatMap { $0.snapshot }, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var location: String? {
        get {
          return snapshot["location"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "location")
        }
      }

      public var scenario: OvertimeScenario {
        get {
          return snapshot["scenario"]! as! OvertimeScenario
        }
        set {
          snapshot.updateValue(newValue, forKey: "scenario")
        }
      }

      public var startsAt: String {
        get {
          return snapshot["startsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "startsAt")
        }
      }

      public var endsAt: String {
        get {
          return snapshot["endsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "endsAt")
        }
      }

      public var slots: Int {
        get {
          return snapshot["slots"]! as! Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "slots")
        }
      }

      public var policySnapshot: String {
        get {
          return snapshot["policySnapshot"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "policySnapshot")
        }
      }

      public var selectionPolicy: OvertimeSelectionPolicy? {
        get {
          return snapshot["selectionPolicy"] as? OvertimeSelectionPolicy
        }
        set {
          snapshot.updateValue(newValue, forKey: "selectionPolicy")
        }
      }

      public var needsEscalation: Bool? {
        get {
          return snapshot["needsEscalation"] as? Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "needsEscalation")
        }
      }

      public var state: OvertimePostingState {
        get {
          return snapshot["state"]! as! OvertimePostingState
        }
        set {
          snapshot.updateValue(newValue, forKey: "state")
        }
      }

      public var createdBy: String {
        get {
          return snapshot["createdBy"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdBy")
        }
      }

      public var invites: Invite? {
        get {
          return (snapshot["invites"] as? Snapshot).flatMap { Invite(snapshot: $0) }
        }
        set {
          snapshot.updateValue(newValue?.snapshot, forKey: "invites")
        }
      }

      public var auditTrail: AuditTrail? {
        get {
          return (snapshot["auditTrail"] as? Snapshot).flatMap { AuditTrail(snapshot: $0) }
        }
        set {
          snapshot.updateValue(newValue?.snapshot, forKey: "auditTrail")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }

      public struct Invite: GraphQLSelectionSet {
        public static let possibleTypes = ["ModelOvertimeInviteConnection"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("nextToken", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(nextToken: String? = nil) {
          self.init(snapshot: ["__typename": "ModelOvertimeInviteConnection", "nextToken": nextToken])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var nextToken: String? {
          get {
            return snapshot["nextToken"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "nextToken")
          }
        }
      }

      public struct AuditTrail: GraphQLSelectionSet {
        public static let possibleTypes = ["ModelOvertimeAuditEventConnection"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("nextToken", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(nextToken: String? = nil) {
          self.init(snapshot: ["__typename": "ModelOvertimeAuditEventConnection", "nextToken": nextToken])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var nextToken: String? {
          get {
            return snapshot["nextToken"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "nextToken")
          }
        }
      }
    }
  }
}

public final class OnUpdateOvertimePostingSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnUpdateOvertimePosting($filter: ModelSubscriptionOvertimePostingFilterInput, $createdBy: String) {\n  onUpdateOvertimePosting(filter: $filter, createdBy: $createdBy) {\n    __typename\n    id\n    orgId\n    title\n    location\n    scenario\n    startsAt\n    endsAt\n    slots\n    policySnapshot\n    selectionPolicy\n    needsEscalation\n    state\n    createdBy\n    invites {\n      __typename\n      nextToken\n    }\n    auditTrail {\n      __typename\n      nextToken\n    }\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionOvertimePostingFilterInput?
  public var createdBy: String?

  public init(filter: ModelSubscriptionOvertimePostingFilterInput? = nil, createdBy: String? = nil) {
    self.filter = filter
    self.createdBy = createdBy
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "createdBy": createdBy]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onUpdateOvertimePosting", arguments: ["filter": GraphQLVariable("filter"), "createdBy": GraphQLVariable("createdBy")], type: .object(OnUpdateOvertimePosting.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onUpdateOvertimePosting: OnUpdateOvertimePosting? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onUpdateOvertimePosting": onUpdateOvertimePosting.flatMap { $0.snapshot }])
    }

    public var onUpdateOvertimePosting: OnUpdateOvertimePosting? {
      get {
        return (snapshot["onUpdateOvertimePosting"] as? Snapshot).flatMap { OnUpdateOvertimePosting(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onUpdateOvertimePosting")
      }
    }

    public struct OnUpdateOvertimePosting: GraphQLSelectionSet {
      public static let possibleTypes = ["OvertimePosting"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("location", type: .scalar(String.self)),
        GraphQLField("scenario", type: .nonNull(.scalar(OvertimeScenario.self))),
        GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("slots", type: .nonNull(.scalar(Int.self))),
        GraphQLField("policySnapshot", type: .nonNull(.scalar(String.self))),
        GraphQLField("selectionPolicy", type: .scalar(OvertimeSelectionPolicy.self)),
        GraphQLField("needsEscalation", type: .scalar(Bool.self)),
        GraphQLField("state", type: .nonNull(.scalar(OvertimePostingState.self))),
        GraphQLField("createdBy", type: .nonNull(.scalar(String.self))),
        GraphQLField("invites", type: .object(Invite.selections)),
        GraphQLField("auditTrail", type: .object(AuditTrail.selections)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, title: String, location: String? = nil, scenario: OvertimeScenario, startsAt: String, endsAt: String, slots: Int, policySnapshot: String, selectionPolicy: OvertimeSelectionPolicy? = nil, needsEscalation: Bool? = nil, state: OvertimePostingState, createdBy: String, invites: Invite? = nil, auditTrail: AuditTrail? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "OvertimePosting", "id": id, "orgId": orgId, "title": title, "location": location, "scenario": scenario, "startsAt": startsAt, "endsAt": endsAt, "slots": slots, "policySnapshot": policySnapshot, "selectionPolicy": selectionPolicy, "needsEscalation": needsEscalation, "state": state, "createdBy": createdBy, "invites": invites.flatMap { $0.snapshot }, "auditTrail": auditTrail.flatMap { $0.snapshot }, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var location: String? {
        get {
          return snapshot["location"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "location")
        }
      }

      public var scenario: OvertimeScenario {
        get {
          return snapshot["scenario"]! as! OvertimeScenario
        }
        set {
          snapshot.updateValue(newValue, forKey: "scenario")
        }
      }

      public var startsAt: String {
        get {
          return snapshot["startsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "startsAt")
        }
      }

      public var endsAt: String {
        get {
          return snapshot["endsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "endsAt")
        }
      }

      public var slots: Int {
        get {
          return snapshot["slots"]! as! Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "slots")
        }
      }

      public var policySnapshot: String {
        get {
          return snapshot["policySnapshot"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "policySnapshot")
        }
      }

      public var selectionPolicy: OvertimeSelectionPolicy? {
        get {
          return snapshot["selectionPolicy"] as? OvertimeSelectionPolicy
        }
        set {
          snapshot.updateValue(newValue, forKey: "selectionPolicy")
        }
      }

      public var needsEscalation: Bool? {
        get {
          return snapshot["needsEscalation"] as? Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "needsEscalation")
        }
      }

      public var state: OvertimePostingState {
        get {
          return snapshot["state"]! as! OvertimePostingState
        }
        set {
          snapshot.updateValue(newValue, forKey: "state")
        }
      }

      public var createdBy: String {
        get {
          return snapshot["createdBy"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdBy")
        }
      }

      public var invites: Invite? {
        get {
          return (snapshot["invites"] as? Snapshot).flatMap { Invite(snapshot: $0) }
        }
        set {
          snapshot.updateValue(newValue?.snapshot, forKey: "invites")
        }
      }

      public var auditTrail: AuditTrail? {
        get {
          return (snapshot["auditTrail"] as? Snapshot).flatMap { AuditTrail(snapshot: $0) }
        }
        set {
          snapshot.updateValue(newValue?.snapshot, forKey: "auditTrail")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }

      public struct Invite: GraphQLSelectionSet {
        public static let possibleTypes = ["ModelOvertimeInviteConnection"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("nextToken", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(nextToken: String? = nil) {
          self.init(snapshot: ["__typename": "ModelOvertimeInviteConnection", "nextToken": nextToken])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var nextToken: String? {
          get {
            return snapshot["nextToken"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "nextToken")
          }
        }
      }

      public struct AuditTrail: GraphQLSelectionSet {
        public static let possibleTypes = ["ModelOvertimeAuditEventConnection"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("nextToken", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(nextToken: String? = nil) {
          self.init(snapshot: ["__typename": "ModelOvertimeAuditEventConnection", "nextToken": nextToken])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var nextToken: String? {
          get {
            return snapshot["nextToken"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "nextToken")
          }
        }
      }
    }
  }
}

public final class OnDeleteOvertimePostingSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnDeleteOvertimePosting($filter: ModelSubscriptionOvertimePostingFilterInput, $createdBy: String) {\n  onDeleteOvertimePosting(filter: $filter, createdBy: $createdBy) {\n    __typename\n    id\n    orgId\n    title\n    location\n    scenario\n    startsAt\n    endsAt\n    slots\n    policySnapshot\n    selectionPolicy\n    needsEscalation\n    state\n    createdBy\n    invites {\n      __typename\n      nextToken\n    }\n    auditTrail {\n      __typename\n      nextToken\n    }\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionOvertimePostingFilterInput?
  public var createdBy: String?

  public init(filter: ModelSubscriptionOvertimePostingFilterInput? = nil, createdBy: String? = nil) {
    self.filter = filter
    self.createdBy = createdBy
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "createdBy": createdBy]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onDeleteOvertimePosting", arguments: ["filter": GraphQLVariable("filter"), "createdBy": GraphQLVariable("createdBy")], type: .object(OnDeleteOvertimePosting.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onDeleteOvertimePosting: OnDeleteOvertimePosting? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onDeleteOvertimePosting": onDeleteOvertimePosting.flatMap { $0.snapshot }])
    }

    public var onDeleteOvertimePosting: OnDeleteOvertimePosting? {
      get {
        return (snapshot["onDeleteOvertimePosting"] as? Snapshot).flatMap { OnDeleteOvertimePosting(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onDeleteOvertimePosting")
      }
    }

    public struct OnDeleteOvertimePosting: GraphQLSelectionSet {
      public static let possibleTypes = ["OvertimePosting"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("location", type: .scalar(String.self)),
        GraphQLField("scenario", type: .nonNull(.scalar(OvertimeScenario.self))),
        GraphQLField("startsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("endsAt", type: .nonNull(.scalar(String.self))),
        GraphQLField("slots", type: .nonNull(.scalar(Int.self))),
        GraphQLField("policySnapshot", type: .nonNull(.scalar(String.self))),
        GraphQLField("selectionPolicy", type: .scalar(OvertimeSelectionPolicy.self)),
        GraphQLField("needsEscalation", type: .scalar(Bool.self)),
        GraphQLField("state", type: .nonNull(.scalar(OvertimePostingState.self))),
        GraphQLField("createdBy", type: .nonNull(.scalar(String.self))),
        GraphQLField("invites", type: .object(Invite.selections)),
        GraphQLField("auditTrail", type: .object(AuditTrail.selections)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, title: String, location: String? = nil, scenario: OvertimeScenario, startsAt: String, endsAt: String, slots: Int, policySnapshot: String, selectionPolicy: OvertimeSelectionPolicy? = nil, needsEscalation: Bool? = nil, state: OvertimePostingState, createdBy: String, invites: Invite? = nil, auditTrail: AuditTrail? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "OvertimePosting", "id": id, "orgId": orgId, "title": title, "location": location, "scenario": scenario, "startsAt": startsAt, "endsAt": endsAt, "slots": slots, "policySnapshot": policySnapshot, "selectionPolicy": selectionPolicy, "needsEscalation": needsEscalation, "state": state, "createdBy": createdBy, "invites": invites.flatMap { $0.snapshot }, "auditTrail": auditTrail.flatMap { $0.snapshot }, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var location: String? {
        get {
          return snapshot["location"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "location")
        }
      }

      public var scenario: OvertimeScenario {
        get {
          return snapshot["scenario"]! as! OvertimeScenario
        }
        set {
          snapshot.updateValue(newValue, forKey: "scenario")
        }
      }

      public var startsAt: String {
        get {
          return snapshot["startsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "startsAt")
        }
      }

      public var endsAt: String {
        get {
          return snapshot["endsAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "endsAt")
        }
      }

      public var slots: Int {
        get {
          return snapshot["slots"]! as! Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "slots")
        }
      }

      public var policySnapshot: String {
        get {
          return snapshot["policySnapshot"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "policySnapshot")
        }
      }

      public var selectionPolicy: OvertimeSelectionPolicy? {
        get {
          return snapshot["selectionPolicy"] as? OvertimeSelectionPolicy
        }
        set {
          snapshot.updateValue(newValue, forKey: "selectionPolicy")
        }
      }

      public var needsEscalation: Bool? {
        get {
          return snapshot["needsEscalation"] as? Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "needsEscalation")
        }
      }

      public var state: OvertimePostingState {
        get {
          return snapshot["state"]! as! OvertimePostingState
        }
        set {
          snapshot.updateValue(newValue, forKey: "state")
        }
      }

      public var createdBy: String {
        get {
          return snapshot["createdBy"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdBy")
        }
      }

      public var invites: Invite? {
        get {
          return (snapshot["invites"] as? Snapshot).flatMap { Invite(snapshot: $0) }
        }
        set {
          snapshot.updateValue(newValue?.snapshot, forKey: "invites")
        }
      }

      public var auditTrail: AuditTrail? {
        get {
          return (snapshot["auditTrail"] as? Snapshot).flatMap { AuditTrail(snapshot: $0) }
        }
        set {
          snapshot.updateValue(newValue?.snapshot, forKey: "auditTrail")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }

      public struct Invite: GraphQLSelectionSet {
        public static let possibleTypes = ["ModelOvertimeInviteConnection"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("nextToken", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(nextToken: String? = nil) {
          self.init(snapshot: ["__typename": "ModelOvertimeInviteConnection", "nextToken": nextToken])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var nextToken: String? {
          get {
            return snapshot["nextToken"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "nextToken")
          }
        }
      }

      public struct AuditTrail: GraphQLSelectionSet {
        public static let possibleTypes = ["ModelOvertimeAuditEventConnection"]

        public static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("nextToken", type: .scalar(String.self)),
        ]

        public var snapshot: Snapshot

        public init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        public init(nextToken: String? = nil) {
          self.init(snapshot: ["__typename": "ModelOvertimeAuditEventConnection", "nextToken": nextToken])
        }

        public var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        public var nextToken: String? {
          get {
            return snapshot["nextToken"] as? String
          }
          set {
            snapshot.updateValue(newValue, forKey: "nextToken")
          }
        }
      }
    }
  }
}

public final class OnCreateOvertimeInviteSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnCreateOvertimeInvite($filter: ModelSubscriptionOvertimeInviteFilterInput, $officerId: String) {\n  onCreateOvertimeInvite(filter: $filter, officerId: $officerId) {\n    __typename\n    id\n    postingId\n    officerId\n    bucket\n    sequence\n    reason\n    status\n    respondedAt\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionOvertimeInviteFilterInput?
  public var officerId: String?

  public init(filter: ModelSubscriptionOvertimeInviteFilterInput? = nil, officerId: String? = nil) {
    self.filter = filter
    self.officerId = officerId
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "officerId": officerId]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onCreateOvertimeInvite", arguments: ["filter": GraphQLVariable("filter"), "officerId": GraphQLVariable("officerId")], type: .object(OnCreateOvertimeInvite.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onCreateOvertimeInvite: OnCreateOvertimeInvite? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onCreateOvertimeInvite": onCreateOvertimeInvite.flatMap { $0.snapshot }])
    }

    public var onCreateOvertimeInvite: OnCreateOvertimeInvite? {
      get {
        return (snapshot["onCreateOvertimeInvite"] as? Snapshot).flatMap { OnCreateOvertimeInvite(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onCreateOvertimeInvite")
      }
    }

    public struct OnCreateOvertimeInvite: GraphQLSelectionSet {
      public static let possibleTypes = ["OvertimeInvite"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("postingId", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("officerId", type: .nonNull(.scalar(String.self))),
        GraphQLField("bucket", type: .nonNull(.scalar(String.self))),
        GraphQLField("sequence", type: .nonNull(.scalar(Int.self))),
        GraphQLField("reason", type: .nonNull(.scalar(String.self))),
        GraphQLField("status", type: .nonNull(.scalar(OvertimeInviteStatus.self))),
        GraphQLField("respondedAt", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, postingId: GraphQLID, officerId: String, bucket: String, sequence: Int, reason: String, status: OvertimeInviteStatus, respondedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "OvertimeInvite", "id": id, "postingId": postingId, "officerId": officerId, "bucket": bucket, "sequence": sequence, "reason": reason, "status": status, "respondedAt": respondedAt, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var postingId: GraphQLID {
        get {
          return snapshot["postingId"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "postingId")
        }
      }

      public var officerId: String {
        get {
          return snapshot["officerId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "officerId")
        }
      }

      public var bucket: String {
        get {
          return snapshot["bucket"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "bucket")
        }
      }

      public var sequence: Int {
        get {
          return snapshot["sequence"]! as! Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "sequence")
        }
      }

      public var reason: String {
        get {
          return snapshot["reason"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "reason")
        }
      }

      public var status: OvertimeInviteStatus {
        get {
          return snapshot["status"]! as! OvertimeInviteStatus
        }
        set {
          snapshot.updateValue(newValue, forKey: "status")
        }
      }

      public var respondedAt: String? {
        get {
          return snapshot["respondedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "respondedAt")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnUpdateOvertimeInviteSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnUpdateOvertimeInvite($filter: ModelSubscriptionOvertimeInviteFilterInput, $officerId: String) {\n  onUpdateOvertimeInvite(filter: $filter, officerId: $officerId) {\n    __typename\n    id\n    postingId\n    officerId\n    bucket\n    sequence\n    reason\n    status\n    respondedAt\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionOvertimeInviteFilterInput?
  public var officerId: String?

  public init(filter: ModelSubscriptionOvertimeInviteFilterInput? = nil, officerId: String? = nil) {
    self.filter = filter
    self.officerId = officerId
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "officerId": officerId]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onUpdateOvertimeInvite", arguments: ["filter": GraphQLVariable("filter"), "officerId": GraphQLVariable("officerId")], type: .object(OnUpdateOvertimeInvite.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onUpdateOvertimeInvite: OnUpdateOvertimeInvite? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onUpdateOvertimeInvite": onUpdateOvertimeInvite.flatMap { $0.snapshot }])
    }

    public var onUpdateOvertimeInvite: OnUpdateOvertimeInvite? {
      get {
        return (snapshot["onUpdateOvertimeInvite"] as? Snapshot).flatMap { OnUpdateOvertimeInvite(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onUpdateOvertimeInvite")
      }
    }

    public struct OnUpdateOvertimeInvite: GraphQLSelectionSet {
      public static let possibleTypes = ["OvertimeInvite"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("postingId", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("officerId", type: .nonNull(.scalar(String.self))),
        GraphQLField("bucket", type: .nonNull(.scalar(String.self))),
        GraphQLField("sequence", type: .nonNull(.scalar(Int.self))),
        GraphQLField("reason", type: .nonNull(.scalar(String.self))),
        GraphQLField("status", type: .nonNull(.scalar(OvertimeInviteStatus.self))),
        GraphQLField("respondedAt", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, postingId: GraphQLID, officerId: String, bucket: String, sequence: Int, reason: String, status: OvertimeInviteStatus, respondedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "OvertimeInvite", "id": id, "postingId": postingId, "officerId": officerId, "bucket": bucket, "sequence": sequence, "reason": reason, "status": status, "respondedAt": respondedAt, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var postingId: GraphQLID {
        get {
          return snapshot["postingId"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "postingId")
        }
      }

      public var officerId: String {
        get {
          return snapshot["officerId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "officerId")
        }
      }

      public var bucket: String {
        get {
          return snapshot["bucket"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "bucket")
        }
      }

      public var sequence: Int {
        get {
          return snapshot["sequence"]! as! Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "sequence")
        }
      }

      public var reason: String {
        get {
          return snapshot["reason"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "reason")
        }
      }

      public var status: OvertimeInviteStatus {
        get {
          return snapshot["status"]! as! OvertimeInviteStatus
        }
        set {
          snapshot.updateValue(newValue, forKey: "status")
        }
      }

      public var respondedAt: String? {
        get {
          return snapshot["respondedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "respondedAt")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnDeleteOvertimeInviteSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnDeleteOvertimeInvite($filter: ModelSubscriptionOvertimeInviteFilterInput, $officerId: String) {\n  onDeleteOvertimeInvite(filter: $filter, officerId: $officerId) {\n    __typename\n    id\n    postingId\n    officerId\n    bucket\n    sequence\n    reason\n    status\n    respondedAt\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionOvertimeInviteFilterInput?
  public var officerId: String?

  public init(filter: ModelSubscriptionOvertimeInviteFilterInput? = nil, officerId: String? = nil) {
    self.filter = filter
    self.officerId = officerId
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "officerId": officerId]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onDeleteOvertimeInvite", arguments: ["filter": GraphQLVariable("filter"), "officerId": GraphQLVariable("officerId")], type: .object(OnDeleteOvertimeInvite.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onDeleteOvertimeInvite: OnDeleteOvertimeInvite? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onDeleteOvertimeInvite": onDeleteOvertimeInvite.flatMap { $0.snapshot }])
    }

    public var onDeleteOvertimeInvite: OnDeleteOvertimeInvite? {
      get {
        return (snapshot["onDeleteOvertimeInvite"] as? Snapshot).flatMap { OnDeleteOvertimeInvite(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onDeleteOvertimeInvite")
      }
    }

    public struct OnDeleteOvertimeInvite: GraphQLSelectionSet {
      public static let possibleTypes = ["OvertimeInvite"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("postingId", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("officerId", type: .nonNull(.scalar(String.self))),
        GraphQLField("bucket", type: .nonNull(.scalar(String.self))),
        GraphQLField("sequence", type: .nonNull(.scalar(Int.self))),
        GraphQLField("reason", type: .nonNull(.scalar(String.self))),
        GraphQLField("status", type: .nonNull(.scalar(OvertimeInviteStatus.self))),
        GraphQLField("respondedAt", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, postingId: GraphQLID, officerId: String, bucket: String, sequence: Int, reason: String, status: OvertimeInviteStatus, respondedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "OvertimeInvite", "id": id, "postingId": postingId, "officerId": officerId, "bucket": bucket, "sequence": sequence, "reason": reason, "status": status, "respondedAt": respondedAt, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var postingId: GraphQLID {
        get {
          return snapshot["postingId"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "postingId")
        }
      }

      public var officerId: String {
        get {
          return snapshot["officerId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "officerId")
        }
      }

      public var bucket: String {
        get {
          return snapshot["bucket"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "bucket")
        }
      }

      public var sequence: Int {
        get {
          return snapshot["sequence"]! as! Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "sequence")
        }
      }

      public var reason: String {
        get {
          return snapshot["reason"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "reason")
        }
      }

      public var status: OvertimeInviteStatus {
        get {
          return snapshot["status"]! as! OvertimeInviteStatus
        }
        set {
          snapshot.updateValue(newValue, forKey: "status")
        }
      }

      public var respondedAt: String? {
        get {
          return snapshot["respondedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "respondedAt")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnCreateOvertimeAuditEventSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnCreateOvertimeAuditEvent($filter: ModelSubscriptionOvertimeAuditEventFilterInput) {\n  onCreateOvertimeAuditEvent(filter: $filter) {\n    __typename\n    id\n    postingId\n    type\n    details\n    createdBy\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionOvertimeAuditEventFilterInput?

  public init(filter: ModelSubscriptionOvertimeAuditEventFilterInput? = nil) {
    self.filter = filter
  }

  public var variables: GraphQLMap? {
    return ["filter": filter]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onCreateOvertimeAuditEvent", arguments: ["filter": GraphQLVariable("filter")], type: .object(OnCreateOvertimeAuditEvent.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onCreateOvertimeAuditEvent: OnCreateOvertimeAuditEvent? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onCreateOvertimeAuditEvent": onCreateOvertimeAuditEvent.flatMap { $0.snapshot }])
    }

    public var onCreateOvertimeAuditEvent: OnCreateOvertimeAuditEvent? {
      get {
        return (snapshot["onCreateOvertimeAuditEvent"] as? Snapshot).flatMap { OnCreateOvertimeAuditEvent(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onCreateOvertimeAuditEvent")
      }
    }

    public struct OnCreateOvertimeAuditEvent: GraphQLSelectionSet {
      public static let possibleTypes = ["OvertimeAuditEvent"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("postingId", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("type", type: .nonNull(.scalar(String.self))),
        GraphQLField("details", type: .scalar(String.self)),
        GraphQLField("createdBy", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .nonNull(.scalar(String.self))),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, postingId: GraphQLID, type: String, details: String? = nil, createdBy: String? = nil, createdAt: String? = nil, updatedAt: String) {
        self.init(snapshot: ["__typename": "OvertimeAuditEvent", "id": id, "postingId": postingId, "type": type, "details": details, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var postingId: GraphQLID {
        get {
          return snapshot["postingId"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "postingId")
        }
      }

      public var type: String {
        get {
          return snapshot["type"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "type")
        }
      }

      public var details: String? {
        get {
          return snapshot["details"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "details")
        }
      }

      public var createdBy: String? {
        get {
          return snapshot["createdBy"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdBy")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String {
        get {
          return snapshot["updatedAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnUpdateOvertimeAuditEventSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnUpdateOvertimeAuditEvent($filter: ModelSubscriptionOvertimeAuditEventFilterInput) {\n  onUpdateOvertimeAuditEvent(filter: $filter) {\n    __typename\n    id\n    postingId\n    type\n    details\n    createdBy\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionOvertimeAuditEventFilterInput?

  public init(filter: ModelSubscriptionOvertimeAuditEventFilterInput? = nil) {
    self.filter = filter
  }

  public var variables: GraphQLMap? {
    return ["filter": filter]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onUpdateOvertimeAuditEvent", arguments: ["filter": GraphQLVariable("filter")], type: .object(OnUpdateOvertimeAuditEvent.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onUpdateOvertimeAuditEvent: OnUpdateOvertimeAuditEvent? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onUpdateOvertimeAuditEvent": onUpdateOvertimeAuditEvent.flatMap { $0.snapshot }])
    }

    public var onUpdateOvertimeAuditEvent: OnUpdateOvertimeAuditEvent? {
      get {
        return (snapshot["onUpdateOvertimeAuditEvent"] as? Snapshot).flatMap { OnUpdateOvertimeAuditEvent(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onUpdateOvertimeAuditEvent")
      }
    }

    public struct OnUpdateOvertimeAuditEvent: GraphQLSelectionSet {
      public static let possibleTypes = ["OvertimeAuditEvent"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("postingId", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("type", type: .nonNull(.scalar(String.self))),
        GraphQLField("details", type: .scalar(String.self)),
        GraphQLField("createdBy", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .nonNull(.scalar(String.self))),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, postingId: GraphQLID, type: String, details: String? = nil, createdBy: String? = nil, createdAt: String? = nil, updatedAt: String) {
        self.init(snapshot: ["__typename": "OvertimeAuditEvent", "id": id, "postingId": postingId, "type": type, "details": details, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var postingId: GraphQLID {
        get {
          return snapshot["postingId"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "postingId")
        }
      }

      public var type: String {
        get {
          return snapshot["type"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "type")
        }
      }

      public var details: String? {
        get {
          return snapshot["details"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "details")
        }
      }

      public var createdBy: String? {
        get {
          return snapshot["createdBy"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdBy")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String {
        get {
          return snapshot["updatedAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnDeleteOvertimeAuditEventSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnDeleteOvertimeAuditEvent($filter: ModelSubscriptionOvertimeAuditEventFilterInput) {\n  onDeleteOvertimeAuditEvent(filter: $filter) {\n    __typename\n    id\n    postingId\n    type\n    details\n    createdBy\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionOvertimeAuditEventFilterInput?

  public init(filter: ModelSubscriptionOvertimeAuditEventFilterInput? = nil) {
    self.filter = filter
  }

  public var variables: GraphQLMap? {
    return ["filter": filter]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onDeleteOvertimeAuditEvent", arguments: ["filter": GraphQLVariable("filter")], type: .object(OnDeleteOvertimeAuditEvent.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onDeleteOvertimeAuditEvent: OnDeleteOvertimeAuditEvent? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onDeleteOvertimeAuditEvent": onDeleteOvertimeAuditEvent.flatMap { $0.snapshot }])
    }

    public var onDeleteOvertimeAuditEvent: OnDeleteOvertimeAuditEvent? {
      get {
        return (snapshot["onDeleteOvertimeAuditEvent"] as? Snapshot).flatMap { OnDeleteOvertimeAuditEvent(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onDeleteOvertimeAuditEvent")
      }
    }

    public struct OnDeleteOvertimeAuditEvent: GraphQLSelectionSet {
      public static let possibleTypes = ["OvertimeAuditEvent"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("postingId", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("type", type: .nonNull(.scalar(String.self))),
        GraphQLField("details", type: .scalar(String.self)),
        GraphQLField("createdBy", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .nonNull(.scalar(String.self))),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, postingId: GraphQLID, type: String, details: String? = nil, createdBy: String? = nil, createdAt: String? = nil, updatedAt: String) {
        self.init(snapshot: ["__typename": "OvertimeAuditEvent", "id": id, "postingId": postingId, "type": type, "details": details, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var postingId: GraphQLID {
        get {
          return snapshot["postingId"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "postingId")
        }
      }

      public var type: String {
        get {
          return snapshot["type"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "type")
        }
      }

      public var details: String? {
        get {
          return snapshot["details"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "details")
        }
      }

      public var createdBy: String? {
        get {
          return snapshot["createdBy"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdBy")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String {
        get {
          return snapshot["updatedAt"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnCreateNotificationEndpointSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnCreateNotificationEndpoint($filter: ModelSubscriptionNotificationEndpointFilterInput, $userId: String) {\n  onCreateNotificationEndpoint(filter: $filter, userId: $userId) {\n    __typename\n    id\n    orgId\n    userId\n    deviceToken\n    platform\n    deviceName\n    enabled\n    platformEndpointArn\n    lastUsedAt\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionNotificationEndpointFilterInput?
  public var userId: String?

  public init(filter: ModelSubscriptionNotificationEndpointFilterInput? = nil, userId: String? = nil) {
    self.filter = filter
    self.userId = userId
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "userId": userId]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onCreateNotificationEndpoint", arguments: ["filter": GraphQLVariable("filter"), "userId": GraphQLVariable("userId")], type: .object(OnCreateNotificationEndpoint.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onCreateNotificationEndpoint: OnCreateNotificationEndpoint? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onCreateNotificationEndpoint": onCreateNotificationEndpoint.flatMap { $0.snapshot }])
    }

    public var onCreateNotificationEndpoint: OnCreateNotificationEndpoint? {
      get {
        return (snapshot["onCreateNotificationEndpoint"] as? Snapshot).flatMap { OnCreateNotificationEndpoint(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onCreateNotificationEndpoint")
      }
    }

    public struct OnCreateNotificationEndpoint: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationEndpoint"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("userId", type: .nonNull(.scalar(String.self))),
        GraphQLField("deviceToken", type: .nonNull(.scalar(String.self))),
        GraphQLField("platform", type: .nonNull(.scalar(NotificationPlatform.self))),
        GraphQLField("deviceName", type: .scalar(String.self)),
        GraphQLField("enabled", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("platformEndpointArn", type: .scalar(String.self)),
        GraphQLField("lastUsedAt", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, userId: String, deviceToken: String, platform: NotificationPlatform, deviceName: String? = nil, enabled: Bool, platformEndpointArn: String? = nil, lastUsedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationEndpoint", "id": id, "orgId": orgId, "userId": userId, "deviceToken": deviceToken, "platform": platform, "deviceName": deviceName, "enabled": enabled, "platformEndpointArn": platformEndpointArn, "lastUsedAt": lastUsedAt, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var userId: String {
        get {
          return snapshot["userId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "userId")
        }
      }

      public var deviceToken: String {
        get {
          return snapshot["deviceToken"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "deviceToken")
        }
      }

      public var platform: NotificationPlatform {
        get {
          return snapshot["platform"]! as! NotificationPlatform
        }
        set {
          snapshot.updateValue(newValue, forKey: "platform")
        }
      }

      public var deviceName: String? {
        get {
          return snapshot["deviceName"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "deviceName")
        }
      }

      public var enabled: Bool {
        get {
          return snapshot["enabled"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "enabled")
        }
      }

      public var platformEndpointArn: String? {
        get {
          return snapshot["platformEndpointArn"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "platformEndpointArn")
        }
      }

      public var lastUsedAt: String? {
        get {
          return snapshot["lastUsedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "lastUsedAt")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnUpdateNotificationEndpointSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnUpdateNotificationEndpoint($filter: ModelSubscriptionNotificationEndpointFilterInput, $userId: String) {\n  onUpdateNotificationEndpoint(filter: $filter, userId: $userId) {\n    __typename\n    id\n    orgId\n    userId\n    deviceToken\n    platform\n    deviceName\n    enabled\n    platformEndpointArn\n    lastUsedAt\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionNotificationEndpointFilterInput?
  public var userId: String?

  public init(filter: ModelSubscriptionNotificationEndpointFilterInput? = nil, userId: String? = nil) {
    self.filter = filter
    self.userId = userId
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "userId": userId]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onUpdateNotificationEndpoint", arguments: ["filter": GraphQLVariable("filter"), "userId": GraphQLVariable("userId")], type: .object(OnUpdateNotificationEndpoint.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onUpdateNotificationEndpoint: OnUpdateNotificationEndpoint? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onUpdateNotificationEndpoint": onUpdateNotificationEndpoint.flatMap { $0.snapshot }])
    }

    public var onUpdateNotificationEndpoint: OnUpdateNotificationEndpoint? {
      get {
        return (snapshot["onUpdateNotificationEndpoint"] as? Snapshot).flatMap { OnUpdateNotificationEndpoint(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onUpdateNotificationEndpoint")
      }
    }

    public struct OnUpdateNotificationEndpoint: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationEndpoint"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("userId", type: .nonNull(.scalar(String.self))),
        GraphQLField("deviceToken", type: .nonNull(.scalar(String.self))),
        GraphQLField("platform", type: .nonNull(.scalar(NotificationPlatform.self))),
        GraphQLField("deviceName", type: .scalar(String.self)),
        GraphQLField("enabled", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("platformEndpointArn", type: .scalar(String.self)),
        GraphQLField("lastUsedAt", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, userId: String, deviceToken: String, platform: NotificationPlatform, deviceName: String? = nil, enabled: Bool, platformEndpointArn: String? = nil, lastUsedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationEndpoint", "id": id, "orgId": orgId, "userId": userId, "deviceToken": deviceToken, "platform": platform, "deviceName": deviceName, "enabled": enabled, "platformEndpointArn": platformEndpointArn, "lastUsedAt": lastUsedAt, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var userId: String {
        get {
          return snapshot["userId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "userId")
        }
      }

      public var deviceToken: String {
        get {
          return snapshot["deviceToken"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "deviceToken")
        }
      }

      public var platform: NotificationPlatform {
        get {
          return snapshot["platform"]! as! NotificationPlatform
        }
        set {
          snapshot.updateValue(newValue, forKey: "platform")
        }
      }

      public var deviceName: String? {
        get {
          return snapshot["deviceName"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "deviceName")
        }
      }

      public var enabled: Bool {
        get {
          return snapshot["enabled"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "enabled")
        }
      }

      public var platformEndpointArn: String? {
        get {
          return snapshot["platformEndpointArn"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "platformEndpointArn")
        }
      }

      public var lastUsedAt: String? {
        get {
          return snapshot["lastUsedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "lastUsedAt")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnDeleteNotificationEndpointSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnDeleteNotificationEndpoint($filter: ModelSubscriptionNotificationEndpointFilterInput, $userId: String) {\n  onDeleteNotificationEndpoint(filter: $filter, userId: $userId) {\n    __typename\n    id\n    orgId\n    userId\n    deviceToken\n    platform\n    deviceName\n    enabled\n    platformEndpointArn\n    lastUsedAt\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionNotificationEndpointFilterInput?
  public var userId: String?

  public init(filter: ModelSubscriptionNotificationEndpointFilterInput? = nil, userId: String? = nil) {
    self.filter = filter
    self.userId = userId
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "userId": userId]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onDeleteNotificationEndpoint", arguments: ["filter": GraphQLVariable("filter"), "userId": GraphQLVariable("userId")], type: .object(OnDeleteNotificationEndpoint.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onDeleteNotificationEndpoint: OnDeleteNotificationEndpoint? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onDeleteNotificationEndpoint": onDeleteNotificationEndpoint.flatMap { $0.snapshot }])
    }

    public var onDeleteNotificationEndpoint: OnDeleteNotificationEndpoint? {
      get {
        return (snapshot["onDeleteNotificationEndpoint"] as? Snapshot).flatMap { OnDeleteNotificationEndpoint(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onDeleteNotificationEndpoint")
      }
    }

    public struct OnDeleteNotificationEndpoint: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationEndpoint"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("userId", type: .nonNull(.scalar(String.self))),
        GraphQLField("deviceToken", type: .nonNull(.scalar(String.self))),
        GraphQLField("platform", type: .nonNull(.scalar(NotificationPlatform.self))),
        GraphQLField("deviceName", type: .scalar(String.self)),
        GraphQLField("enabled", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("platformEndpointArn", type: .scalar(String.self)),
        GraphQLField("lastUsedAt", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, userId: String, deviceToken: String, platform: NotificationPlatform, deviceName: String? = nil, enabled: Bool, platformEndpointArn: String? = nil, lastUsedAt: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationEndpoint", "id": id, "orgId": orgId, "userId": userId, "deviceToken": deviceToken, "platform": platform, "deviceName": deviceName, "enabled": enabled, "platformEndpointArn": platformEndpointArn, "lastUsedAt": lastUsedAt, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var userId: String {
        get {
          return snapshot["userId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "userId")
        }
      }

      public var deviceToken: String {
        get {
          return snapshot["deviceToken"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "deviceToken")
        }
      }

      public var platform: NotificationPlatform {
        get {
          return snapshot["platform"]! as! NotificationPlatform
        }
        set {
          snapshot.updateValue(newValue, forKey: "platform")
        }
      }

      public var deviceName: String? {
        get {
          return snapshot["deviceName"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "deviceName")
        }
      }

      public var enabled: Bool {
        get {
          return snapshot["enabled"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "enabled")
        }
      }

      public var platformEndpointArn: String? {
        get {
          return snapshot["platformEndpointArn"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "platformEndpointArn")
        }
      }

      public var lastUsedAt: String? {
        get {
          return snapshot["lastUsedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "lastUsedAt")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnCreateNotificationMessageSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnCreateNotificationMessage($filter: ModelSubscriptionNotificationMessageFilterInput) {\n  onCreateNotificationMessage(filter: $filter) {\n    __typename\n    id\n    orgId\n    title\n    body\n    category\n    recipients\n    metadata\n    createdBy\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionNotificationMessageFilterInput?

  public init(filter: ModelSubscriptionNotificationMessageFilterInput? = nil) {
    self.filter = filter
  }

  public var variables: GraphQLMap? {
    return ["filter": filter]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onCreateNotificationMessage", arguments: ["filter": GraphQLVariable("filter")], type: .object(OnCreateNotificationMessage.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onCreateNotificationMessage: OnCreateNotificationMessage? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onCreateNotificationMessage": onCreateNotificationMessage.flatMap { $0.snapshot }])
    }

    public var onCreateNotificationMessage: OnCreateNotificationMessage? {
      get {
        return (snapshot["onCreateNotificationMessage"] as? Snapshot).flatMap { OnCreateNotificationMessage(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onCreateNotificationMessage")
      }
    }

    public struct OnCreateNotificationMessage: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationMessage"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("body", type: .nonNull(.scalar(String.self))),
        GraphQLField("category", type: .nonNull(.scalar(NotificationCategory.self))),
        GraphQLField("recipients", type: .nonNull(.list(.nonNull(.scalar(String.self))))),
        GraphQLField("metadata", type: .scalar(String.self)),
        GraphQLField("createdBy", type: .nonNull(.scalar(String.self))),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, title: String, body: String, category: NotificationCategory, recipients: [String], metadata: String? = nil, createdBy: String, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationMessage", "id": id, "orgId": orgId, "title": title, "body": body, "category": category, "recipients": recipients, "metadata": metadata, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var body: String {
        get {
          return snapshot["body"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "body")
        }
      }

      public var category: NotificationCategory {
        get {
          return snapshot["category"]! as! NotificationCategory
        }
        set {
          snapshot.updateValue(newValue, forKey: "category")
        }
      }

      public var recipients: [String] {
        get {
          return snapshot["recipients"]! as! [String]
        }
        set {
          snapshot.updateValue(newValue, forKey: "recipients")
        }
      }

      public var metadata: String? {
        get {
          return snapshot["metadata"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "metadata")
        }
      }

      public var createdBy: String {
        get {
          return snapshot["createdBy"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdBy")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnUpdateNotificationMessageSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnUpdateNotificationMessage($filter: ModelSubscriptionNotificationMessageFilterInput) {\n  onUpdateNotificationMessage(filter: $filter) {\n    __typename\n    id\n    orgId\n    title\n    body\n    category\n    recipients\n    metadata\n    createdBy\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionNotificationMessageFilterInput?

  public init(filter: ModelSubscriptionNotificationMessageFilterInput? = nil) {
    self.filter = filter
  }

  public var variables: GraphQLMap? {
    return ["filter": filter]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onUpdateNotificationMessage", arguments: ["filter": GraphQLVariable("filter")], type: .object(OnUpdateNotificationMessage.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onUpdateNotificationMessage: OnUpdateNotificationMessage? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onUpdateNotificationMessage": onUpdateNotificationMessage.flatMap { $0.snapshot }])
    }

    public var onUpdateNotificationMessage: OnUpdateNotificationMessage? {
      get {
        return (snapshot["onUpdateNotificationMessage"] as? Snapshot).flatMap { OnUpdateNotificationMessage(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onUpdateNotificationMessage")
      }
    }

    public struct OnUpdateNotificationMessage: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationMessage"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("body", type: .nonNull(.scalar(String.self))),
        GraphQLField("category", type: .nonNull(.scalar(NotificationCategory.self))),
        GraphQLField("recipients", type: .nonNull(.list(.nonNull(.scalar(String.self))))),
        GraphQLField("metadata", type: .scalar(String.self)),
        GraphQLField("createdBy", type: .nonNull(.scalar(String.self))),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, title: String, body: String, category: NotificationCategory, recipients: [String], metadata: String? = nil, createdBy: String, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationMessage", "id": id, "orgId": orgId, "title": title, "body": body, "category": category, "recipients": recipients, "metadata": metadata, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var body: String {
        get {
          return snapshot["body"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "body")
        }
      }

      public var category: NotificationCategory {
        get {
          return snapshot["category"]! as! NotificationCategory
        }
        set {
          snapshot.updateValue(newValue, forKey: "category")
        }
      }

      public var recipients: [String] {
        get {
          return snapshot["recipients"]! as! [String]
        }
        set {
          snapshot.updateValue(newValue, forKey: "recipients")
        }
      }

      public var metadata: String? {
        get {
          return snapshot["metadata"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "metadata")
        }
      }

      public var createdBy: String {
        get {
          return snapshot["createdBy"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdBy")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnDeleteNotificationMessageSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnDeleteNotificationMessage($filter: ModelSubscriptionNotificationMessageFilterInput) {\n  onDeleteNotificationMessage(filter: $filter) {\n    __typename\n    id\n    orgId\n    title\n    body\n    category\n    recipients\n    metadata\n    createdBy\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionNotificationMessageFilterInput?

  public init(filter: ModelSubscriptionNotificationMessageFilterInput? = nil) {
    self.filter = filter
  }

  public var variables: GraphQLMap? {
    return ["filter": filter]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onDeleteNotificationMessage", arguments: ["filter": GraphQLVariable("filter")], type: .object(OnDeleteNotificationMessage.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onDeleteNotificationMessage: OnDeleteNotificationMessage? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onDeleteNotificationMessage": onDeleteNotificationMessage.flatMap { $0.snapshot }])
    }

    public var onDeleteNotificationMessage: OnDeleteNotificationMessage? {
      get {
        return (snapshot["onDeleteNotificationMessage"] as? Snapshot).flatMap { OnDeleteNotificationMessage(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onDeleteNotificationMessage")
      }
    }

    public struct OnDeleteNotificationMessage: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationMessage"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("orgId", type: .nonNull(.scalar(String.self))),
        GraphQLField("title", type: .nonNull(.scalar(String.self))),
        GraphQLField("body", type: .nonNull(.scalar(String.self))),
        GraphQLField("category", type: .nonNull(.scalar(NotificationCategory.self))),
        GraphQLField("recipients", type: .nonNull(.list(.nonNull(.scalar(String.self))))),
        GraphQLField("metadata", type: .scalar(String.self)),
        GraphQLField("createdBy", type: .nonNull(.scalar(String.self))),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, orgId: String, title: String, body: String, category: NotificationCategory, recipients: [String], metadata: String? = nil, createdBy: String, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationMessage", "id": id, "orgId": orgId, "title": title, "body": body, "category": category, "recipients": recipients, "metadata": metadata, "createdBy": createdBy, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var orgId: String {
        get {
          return snapshot["orgId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "orgId")
        }
      }

      public var title: String {
        get {
          return snapshot["title"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "title")
        }
      }

      public var body: String {
        get {
          return snapshot["body"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "body")
        }
      }

      public var category: NotificationCategory {
        get {
          return snapshot["category"]! as! NotificationCategory
        }
        set {
          snapshot.updateValue(newValue, forKey: "category")
        }
      }

      public var recipients: [String] {
        get {
          return snapshot["recipients"]! as! [String]
        }
        set {
          snapshot.updateValue(newValue, forKey: "recipients")
        }
      }

      public var metadata: String? {
        get {
          return snapshot["metadata"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "metadata")
        }
      }

      public var createdBy: String {
        get {
          return snapshot["createdBy"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdBy")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnCreateNotificationPreferenceSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnCreateNotificationPreference($filter: ModelSubscriptionNotificationPreferenceFilterInput, $userId: String) {\n  onCreateNotificationPreference(filter: $filter, userId: $userId) {\n    __typename\n    id\n    userId\n    generalBulletin\n    taskAlert\n    overtime\n    squadMessages\n    other\n    contactPhone\n    contactEmail\n    backupEmail\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionNotificationPreferenceFilterInput?
  public var userId: String?

  public init(filter: ModelSubscriptionNotificationPreferenceFilterInput? = nil, userId: String? = nil) {
    self.filter = filter
    self.userId = userId
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "userId": userId]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onCreateNotificationPreference", arguments: ["filter": GraphQLVariable("filter"), "userId": GraphQLVariable("userId")], type: .object(OnCreateNotificationPreference.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onCreateNotificationPreference: OnCreateNotificationPreference? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onCreateNotificationPreference": onCreateNotificationPreference.flatMap { $0.snapshot }])
    }

    public var onCreateNotificationPreference: OnCreateNotificationPreference? {
      get {
        return (snapshot["onCreateNotificationPreference"] as? Snapshot).flatMap { OnCreateNotificationPreference(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onCreateNotificationPreference")
      }
    }

    public struct OnCreateNotificationPreference: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationPreference"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("userId", type: .nonNull(.scalar(String.self))),
        GraphQLField("generalBulletin", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("taskAlert", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("overtime", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("squadMessages", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("other", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("contactPhone", type: .scalar(String.self)),
        GraphQLField("contactEmail", type: .scalar(String.self)),
        GraphQLField("backupEmail", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, userId: String, generalBulletin: Bool, taskAlert: Bool, overtime: Bool, squadMessages: Bool, other: Bool, contactPhone: String? = nil, contactEmail: String? = nil, backupEmail: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationPreference", "id": id, "userId": userId, "generalBulletin": generalBulletin, "taskAlert": taskAlert, "overtime": overtime, "squadMessages": squadMessages, "other": other, "contactPhone": contactPhone, "contactEmail": contactEmail, "backupEmail": backupEmail, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var userId: String {
        get {
          return snapshot["userId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "userId")
        }
      }

      public var generalBulletin: Bool {
        get {
          return snapshot["generalBulletin"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "generalBulletin")
        }
      }

      public var taskAlert: Bool {
        get {
          return snapshot["taskAlert"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "taskAlert")
        }
      }

      public var overtime: Bool {
        get {
          return snapshot["overtime"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "overtime")
        }
      }

      public var squadMessages: Bool {
        get {
          return snapshot["squadMessages"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "squadMessages")
        }
      }

      public var other: Bool {
        get {
          return snapshot["other"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "other")
        }
      }

      public var contactPhone: String? {
        get {
          return snapshot["contactPhone"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "contactPhone")
        }
      }

      public var contactEmail: String? {
        get {
          return snapshot["contactEmail"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "contactEmail")
        }
      }

      public var backupEmail: String? {
        get {
          return snapshot["backupEmail"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "backupEmail")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnUpdateNotificationPreferenceSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnUpdateNotificationPreference($filter: ModelSubscriptionNotificationPreferenceFilterInput, $userId: String) {\n  onUpdateNotificationPreference(filter: $filter, userId: $userId) {\n    __typename\n    id\n    userId\n    generalBulletin\n    taskAlert\n    overtime\n    squadMessages\n    other\n    contactPhone\n    contactEmail\n    backupEmail\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionNotificationPreferenceFilterInput?
  public var userId: String?

  public init(filter: ModelSubscriptionNotificationPreferenceFilterInput? = nil, userId: String? = nil) {
    self.filter = filter
    self.userId = userId
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "userId": userId]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onUpdateNotificationPreference", arguments: ["filter": GraphQLVariable("filter"), "userId": GraphQLVariable("userId")], type: .object(OnUpdateNotificationPreference.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onUpdateNotificationPreference: OnUpdateNotificationPreference? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onUpdateNotificationPreference": onUpdateNotificationPreference.flatMap { $0.snapshot }])
    }

    public var onUpdateNotificationPreference: OnUpdateNotificationPreference? {
      get {
        return (snapshot["onUpdateNotificationPreference"] as? Snapshot).flatMap { OnUpdateNotificationPreference(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onUpdateNotificationPreference")
      }
    }

    public struct OnUpdateNotificationPreference: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationPreference"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("userId", type: .nonNull(.scalar(String.self))),
        GraphQLField("generalBulletin", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("taskAlert", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("overtime", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("squadMessages", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("other", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("contactPhone", type: .scalar(String.self)),
        GraphQLField("contactEmail", type: .scalar(String.self)),
        GraphQLField("backupEmail", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, userId: String, generalBulletin: Bool, taskAlert: Bool, overtime: Bool, squadMessages: Bool, other: Bool, contactPhone: String? = nil, contactEmail: String? = nil, backupEmail: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationPreference", "id": id, "userId": userId, "generalBulletin": generalBulletin, "taskAlert": taskAlert, "overtime": overtime, "squadMessages": squadMessages, "other": other, "contactPhone": contactPhone, "contactEmail": contactEmail, "backupEmail": backupEmail, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var userId: String {
        get {
          return snapshot["userId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "userId")
        }
      }

      public var generalBulletin: Bool {
        get {
          return snapshot["generalBulletin"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "generalBulletin")
        }
      }

      public var taskAlert: Bool {
        get {
          return snapshot["taskAlert"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "taskAlert")
        }
      }

      public var overtime: Bool {
        get {
          return snapshot["overtime"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "overtime")
        }
      }

      public var squadMessages: Bool {
        get {
          return snapshot["squadMessages"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "squadMessages")
        }
      }

      public var other: Bool {
        get {
          return snapshot["other"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "other")
        }
      }

      public var contactPhone: String? {
        get {
          return snapshot["contactPhone"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "contactPhone")
        }
      }

      public var contactEmail: String? {
        get {
          return snapshot["contactEmail"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "contactEmail")
        }
      }

      public var backupEmail: String? {
        get {
          return snapshot["backupEmail"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "backupEmail")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}

public final class OnDeleteNotificationPreferenceSubscription: GraphQLSubscription {
  public static let operationString =
    "subscription OnDeleteNotificationPreference($filter: ModelSubscriptionNotificationPreferenceFilterInput, $userId: String) {\n  onDeleteNotificationPreference(filter: $filter, userId: $userId) {\n    __typename\n    id\n    userId\n    generalBulletin\n    taskAlert\n    overtime\n    squadMessages\n    other\n    contactPhone\n    contactEmail\n    backupEmail\n    createdAt\n    updatedAt\n  }\n}"

  public var filter: ModelSubscriptionNotificationPreferenceFilterInput?
  public var userId: String?

  public init(filter: ModelSubscriptionNotificationPreferenceFilterInput? = nil, userId: String? = nil) {
    self.filter = filter
    self.userId = userId
  }

  public var variables: GraphQLMap? {
    return ["filter": filter, "userId": userId]
  }

  public struct Data: GraphQLSelectionSet {
    public static let possibleTypes = ["Subscription"]

    public static let selections: [GraphQLSelection] = [
      GraphQLField("onDeleteNotificationPreference", arguments: ["filter": GraphQLVariable("filter"), "userId": GraphQLVariable("userId")], type: .object(OnDeleteNotificationPreference.selections)),
    ]

    public var snapshot: Snapshot

    public init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    public init(onDeleteNotificationPreference: OnDeleteNotificationPreference? = nil) {
      self.init(snapshot: ["__typename": "Subscription", "onDeleteNotificationPreference": onDeleteNotificationPreference.flatMap { $0.snapshot }])
    }

    public var onDeleteNotificationPreference: OnDeleteNotificationPreference? {
      get {
        return (snapshot["onDeleteNotificationPreference"] as? Snapshot).flatMap { OnDeleteNotificationPreference(snapshot: $0) }
      }
      set {
        snapshot.updateValue(newValue?.snapshot, forKey: "onDeleteNotificationPreference")
      }
    }

    public struct OnDeleteNotificationPreference: GraphQLSelectionSet {
      public static let possibleTypes = ["NotificationPreference"]

      public static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        GraphQLField("userId", type: .nonNull(.scalar(String.self))),
        GraphQLField("generalBulletin", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("taskAlert", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("overtime", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("squadMessages", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("other", type: .nonNull(.scalar(Bool.self))),
        GraphQLField("contactPhone", type: .scalar(String.self)),
        GraphQLField("contactEmail", type: .scalar(String.self)),
        GraphQLField("backupEmail", type: .scalar(String.self)),
        GraphQLField("createdAt", type: .scalar(String.self)),
        GraphQLField("updatedAt", type: .scalar(String.self)),
      ]

      public var snapshot: Snapshot

      public init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      public init(id: GraphQLID, userId: String, generalBulletin: Bool, taskAlert: Bool, overtime: Bool, squadMessages: Bool, other: Bool, contactPhone: String? = nil, contactEmail: String? = nil, backupEmail: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.init(snapshot: ["__typename": "NotificationPreference", "id": id, "userId": userId, "generalBulletin": generalBulletin, "taskAlert": taskAlert, "overtime": overtime, "squadMessages": squadMessages, "other": other, "contactPhone": contactPhone, "contactEmail": contactEmail, "backupEmail": backupEmail, "createdAt": createdAt, "updatedAt": updatedAt])
      }

      public var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      public var id: GraphQLID {
        get {
          return snapshot["id"]! as! GraphQLID
        }
        set {
          snapshot.updateValue(newValue, forKey: "id")
        }
      }

      public var userId: String {
        get {
          return snapshot["userId"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "userId")
        }
      }

      public var generalBulletin: Bool {
        get {
          return snapshot["generalBulletin"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "generalBulletin")
        }
      }

      public var taskAlert: Bool {
        get {
          return snapshot["taskAlert"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "taskAlert")
        }
      }

      public var overtime: Bool {
        get {
          return snapshot["overtime"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "overtime")
        }
      }

      public var squadMessages: Bool {
        get {
          return snapshot["squadMessages"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "squadMessages")
        }
      }

      public var other: Bool {
        get {
          return snapshot["other"]! as! Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "other")
        }
      }

      public var contactPhone: String? {
        get {
          return snapshot["contactPhone"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "contactPhone")
        }
      }

      public var contactEmail: String? {
        get {
          return snapshot["contactEmail"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "contactEmail")
        }
      }

      public var backupEmail: String? {
        get {
          return snapshot["backupEmail"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "backupEmail")
        }
      }

      public var createdAt: String? {
        get {
          return snapshot["createdAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "createdAt")
        }
      }

      public var updatedAt: String? {
        get {
          return snapshot["updatedAt"] as? String
        }
        set {
          snapshot.updateValue(newValue, forKey: "updatedAt")
        }
      }
    }
  }
}