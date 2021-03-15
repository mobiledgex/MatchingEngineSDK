
// Copyright 2018-2020 MobiledgeX, Inc. All rights and licenses reserved.
// MobiledgeX, Inc. 156 2nd Street #408, San Francisco, CA 94105
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//
//  MatchingEngineProto.swift
//  MatchingEngine Proto Objects
//

extension MobiledgeXiOSLibrary.MatchingEngine {
    
    /// IDTypes used for unique_id_type in RegisterClientRequest??
    public enum IDTypes: String, Codable {
        case ID_UNDEFINED = "ID_UNDEFINED"
        case IMEI = "IMEI"
        case MSISDN = "MSISDN"
        case IPADDR = "IPADDR"
    }
    
    /// Values for RegisterClientReply, DynamicLocGroupReply, and QosPositionKpiReply status field
    public enum ReplyStatus: String, Decodable {
        case RS_UNDEFINED = "RS_UNDEFINED"
        case RS_SUCCESS = "RS_SUCCESS"
        case RS_FAIL = "RS_FAIL"
    }
    
    /// Object returned in ports of several API replies
    public struct AppPort: Decodable {
        public var proto: LProto
        public var internal_port: Int32
        public var public_port: Int32
        public var fqdn_prefix: String?
        public var end_port: Int32?
        public var tls: Bool?
        
        static func == (ap1: AppPort, ap2: AppPort) -> Bool {
            if (ap1.proto != ap2.proto) {
                return false
            }
            if (ap1.internal_port != ap2.internal_port) {
                return false
            }
            if (ap1.public_port != ap2.public_port) {
                return false
            }
            if (ap1.fqdn_prefix != ap2.fqdn_prefix) {
                return false
            }
            if (ap1.end_port != ap2.end_port) {
                return false
            }
            if (ap1.tls != ap2.tls) {
                return false
            }
            return true
        }
    }
    
    /// Values for AppPort proto field
    public enum LProto: String, Decodable {
        case L_PROTO_UNKNOWN = "L_PROTO_UNKNOWN"
        case L_PROTO_TCP = "L_PROTO_TCP"
        case L_PROTO_UDP = "L_PROTO_UDP"
    }
    
    /// Object used in timestamp field of Loc
    public struct Timestamp: Codable {
        public var seconds: Int64?
        public var nanos: Int32?
    }
    
    /// Object used and returned in gps_location field of serveral API requests and replies
    public struct Loc: Codable {
        
        public init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }
        
        public var latitude: Double?
        public var longitude: Double?
        public var horizontal_accuracy: Double?
        public var vertical_accuracy: Double?
        public var altitude: Double?
        public var course: Double?
        public var speed: Double?
        public var timestamp: Timestamp?
    }
}
