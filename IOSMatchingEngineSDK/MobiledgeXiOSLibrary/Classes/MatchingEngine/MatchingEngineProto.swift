
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
    public class Tag {
        public static let type = "type"
        public static let data = "data"
    }
    
    // IDTypes used for unique_id_type in RegisterClientRequest
    public enum IDTypes {
        public static let ID_UNDEFINED = "ID_UNDEFINED"
        public static let IMEI = "IMEI"
        public static let MSISDN = "MSISDN"
        public static let IPADDR = "IPADDR"
    }
    
    // Values for RegisterClientReply, DynamicLocGroupReply, and QosPositionKpiReply status field
    public enum ReplyStatus {
        public static let RS_UNDEFINED = "RS_UNDEFINED"
        public static let RS_SUCCESS = "RS_SUCCESS"
        public static let RS_FAIL = "RS_FAIL"
    }
    
    // Object returned in ports of several API replies
    public class AppPort {
        public static let proto = "proto"
        public static let internal_port = "internal_port"
        public static let public_port = "public_port"
        public static let path_prefix = "path_prefix"
        public static let fqdn_prefix = "fqdn_prefix"
        public static let end_port = "end_port"
        
        
        // Values for AppPort proto field
        public enum LProto {
            public static let L_PROTO_UNKNOWN = "L_PROTO_UNKNOWN"
            public static let L_PROTO_TCP = "L_PROTO_TCP"
            public static let L_PROTO_UDP = "L_PROTO_UDP"
            public static let L_PROTO_HTTP = "L_PROTO_HTTP"
        }
    }
    
    // Object used and returned in gps_location field of serveral API requests and replies
    public class Loc {
        public static let latitude = "latitude"
        public static let longitude = "longitude"
        public static let horizontal_accuracy = "horizontal_accuracy"
        public static let vertical_accuracy = "vertical_accuracy"
        public static let altitude = "altitude"
        public static let course = "course"
        public static let speed = "speed"
        public static let timestamp = "timestamp"
        
        // Object used in timestamp field of Loc
        public class Timestamp {
            public static let seconds = "seconds"
            public static let nanos = "nanos"
        }
    }
}
