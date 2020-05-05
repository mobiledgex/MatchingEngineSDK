
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
    
    // Object in the tags parameter of API requests and replies (tags is an array of Tag objects)
    public struct Tag: Codable {
        public var type: String
        public var data: String
    }
    
    // IDTypes used for unique_id_type in RegisterClientRequest??
    public enum IDTypes: String, Codable {
        case ID_UNDEFINED = "ID_UNDEFINED"
        case IMEI = "IMEI"
        case MSISDN = "MSISDN"
        case IPADDR = "IPADDR"
    }
    
    // Values for RegisterClientReply, DynamicLocGroupReply, and QosPositionKpiReply status field
    public enum ReplyStatus: String, Decodable {
        case RS_UNDEFINED = "RS_UNDEFINED"
        case RS_SUCCESS = "RS_SUCCESS"
        case RS_FAIL = "RS_FAIL"
    }
    
    // Object returned in ports of several API replies
    public struct AppPort: Decodable {
        public var proto: LProto
        public var internal_port: Int32
        public var public_port: Int32
        public var path_prefix: String?
        public var fqdn_prefix: String?
        public var end_port: Int32?
        public var tls: Bool?
    }
    
    // Values for AppPort proto field
    public enum LProto: String, Decodable {
        case L_PROTO_UNKNOWN = "L_PROTO_UNKNOWN"
        case L_PROTO_TCP = "L_PROTO_TCP"
        case L_PROTO_UDP = "L_PROTO_UDP"
        case L_PROTO_HTTP = "L_PROTO_HTTP"
    }
    
    // Object used in timestamp field of Loc
    public struct Timestamp: Codable {
        public var seconds: Int64?
        public var nanos: Int32?
    }
    
    // Object used and returned in gps_location field of serveral API requests and replies
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
