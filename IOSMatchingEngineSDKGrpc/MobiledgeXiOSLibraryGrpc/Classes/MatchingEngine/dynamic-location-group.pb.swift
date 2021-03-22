// DO NOT EDIT.
// swift-format-ignore-file
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: dynamic-location-group.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

// Dynamic Location Group APIs

import Foundation
import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that you are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

public struct DistributedMatchEngine_DlgMessage {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  public var ver: UInt32 = 0

  /// Dynamic Location Group Id
  public var lgID: UInt64 = 0

  /// Group Cookie if secure
  public var groupCookie: String = String()

  /// Message ID
  public var messageID: UInt64 = 0

  public var ackType: DistributedMatchEngine_DlgMessage.DlgAck = .eachMessage

  /// Message
  public var message: String = String()

  public var unknownFields = SwiftProtobuf.UnknownStorage()

  /// Need acknowledgement
  public enum DlgAck: SwiftProtobuf.Enum {
    public typealias RawValue = Int
    case eachMessage // = 0
    case dlgAsyEveryNMessage // = 1
    case dlgNoAck // = 2
    case UNRECOGNIZED(Int)

    public init() {
      self = .eachMessage
    }

    public init?(rawValue: Int) {
      switch rawValue {
      case 0: self = .eachMessage
      case 1: self = .dlgAsyEveryNMessage
      case 2: self = .dlgNoAck
      default: self = .UNRECOGNIZED(rawValue)
      }
    }

    public var rawValue: Int {
      switch self {
      case .eachMessage: return 0
      case .dlgAsyEveryNMessage: return 1
      case .dlgNoAck: return 2
      case .UNRECOGNIZED(let i): return i
      }
    }

  }

  public init() {}
}

#if swift(>=4.2)

extension DistributedMatchEngine_DlgMessage.DlgAck: CaseIterable {
  // The compiler won't synthesize support with the UNRECOGNIZED case.
  public static var allCases: [DistributedMatchEngine_DlgMessage.DlgAck] = [
    .eachMessage,
    .dlgAsyEveryNMessage,
    .dlgNoAck,
  ]
}

#endif  // swift(>=4.2)

public struct DistributedMatchEngine_DlgReply {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  public var ver: UInt32 = 0

  /// AckId
  public var ackID: UInt64 = 0

  /// Group Cookie for Secure comm
  public var groupCookie: String = String()

  public var unknownFields = SwiftProtobuf.UnknownStorage()

  public init() {}
}

// MARK: - Code below here is support for the SwiftProtobuf runtime.

fileprivate let _protobuf_package = "distributed_match_engine"

extension DistributedMatchEngine_DlgMessage: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".DlgMessage"
  public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "ver"),
    2: .standard(proto: "lg_id"),
    3: .standard(proto: "group_cookie"),
    4: .standard(proto: "message_id"),
    5: .standard(proto: "ack_type"),
    6: .same(proto: "message"),
  ]

  public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularUInt32Field(value: &self.ver) }()
      case 2: try { try decoder.decodeSingularUInt64Field(value: &self.lgID) }()
      case 3: try { try decoder.decodeSingularStringField(value: &self.groupCookie) }()
      case 4: try { try decoder.decodeSingularUInt64Field(value: &self.messageID) }()
      case 5: try { try decoder.decodeSingularEnumField(value: &self.ackType) }()
      case 6: try { try decoder.decodeSingularStringField(value: &self.message) }()
      default: break
      }
    }
  }

  public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if self.ver != 0 {
      try visitor.visitSingularUInt32Field(value: self.ver, fieldNumber: 1)
    }
    if self.lgID != 0 {
      try visitor.visitSingularUInt64Field(value: self.lgID, fieldNumber: 2)
    }
    if !self.groupCookie.isEmpty {
      try visitor.visitSingularStringField(value: self.groupCookie, fieldNumber: 3)
    }
    if self.messageID != 0 {
      try visitor.visitSingularUInt64Field(value: self.messageID, fieldNumber: 4)
    }
    if self.ackType != .eachMessage {
      try visitor.visitSingularEnumField(value: self.ackType, fieldNumber: 5)
    }
    if !self.message.isEmpty {
      try visitor.visitSingularStringField(value: self.message, fieldNumber: 6)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: DistributedMatchEngine_DlgMessage, rhs: DistributedMatchEngine_DlgMessage) -> Bool {
    if lhs.ver != rhs.ver {return false}
    if lhs.lgID != rhs.lgID {return false}
    if lhs.groupCookie != rhs.groupCookie {return false}
    if lhs.messageID != rhs.messageID {return false}
    if lhs.ackType != rhs.ackType {return false}
    if lhs.message != rhs.message {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension DistributedMatchEngine_DlgMessage.DlgAck: SwiftProtobuf._ProtoNameProviding {
  public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    0: .same(proto: "DLG_ACK_EACH_MESSAGE"),
    1: .same(proto: "DLG_ASY_EVERY_N_MESSAGE"),
    2: .same(proto: "DLG_NO_ACK"),
  ]
}

extension DistributedMatchEngine_DlgReply: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".DlgReply"
  public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "ver"),
    2: .standard(proto: "ack_id"),
    3: .standard(proto: "group_cookie"),
  ]

  public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularUInt32Field(value: &self.ver) }()
      case 2: try { try decoder.decodeSingularUInt64Field(value: &self.ackID) }()
      case 3: try { try decoder.decodeSingularStringField(value: &self.groupCookie) }()
      default: break
      }
    }
  }

  public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if self.ver != 0 {
      try visitor.visitSingularUInt32Field(value: self.ver, fieldNumber: 1)
    }
    if self.ackID != 0 {
      try visitor.visitSingularUInt64Field(value: self.ackID, fieldNumber: 2)
    }
    if !self.groupCookie.isEmpty {
      try visitor.visitSingularStringField(value: self.groupCookie, fieldNumber: 3)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: DistributedMatchEngine_DlgReply, rhs: DistributedMatchEngine_DlgReply) -> Bool {
    if lhs.ver != rhs.ver {return false}
    if lhs.ackID != rhs.ackID {return false}
    if lhs.groupCookie != rhs.groupCookie {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}