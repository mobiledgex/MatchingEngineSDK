//
//  KeyValTest.swift
//  MatchingEngine
//
//  Created by Franlin Huang on 7/25/19.
//

import Foundation
import NSLogger
import Promises

extension MatchingEngine {
    
    //registerClientRequest fields
    class registerClientRequestFields {
        public static let ver = "ver"
        public static let dev_name = "dev_name"
        public static let app_name = "app_name"
        public static let app_vers = "app_vers"
        public static let carrier_name = "carrier_name"
        public static let auth_token = "auth_token"
    }
    
    //registerClientReply fields
    class registerClientReplyFields {
        public static let ver = "ver"
        public static let status = "status"
        public static let session_cookie = "session_cookie"
        public static let token_server_uri = "token_server_uri"
    }

    //findCloudletRequest fields
    class findCloudletRequestFields {
        public static let ver = "ver"
        public static let session_cookie = "session_cookie"
        public static let carrier_name = "carrier_name"
        public static let gps_location = "gps_location"
        public static let dev_name = "dev_name"
        public static let app_name = "app_name"
        public static let app_vers = "app_vers"
    }
    
    //findCloudletReply fields
    class findCloudletReplyFields {
        public static let ver = "ver"
        public static let status = "status"
        public static let fqdn = "fqdn"
        public static let ports = "ports"
        public static let cloudlet_location = "cloudlet_location"
    }
    
    //verifyLocationRequest fields
    class verifyLocationRequestFields {
        public static let ver = "ver"
        public static let session_cookie = "session_cookie"
        public static let carrier_name = "carrier_name"
        public static let gps_location = "gps_location"
        public static let verify_loc_token = "verify_loc_token"
    }
    
    //verifyLocationReply fields
    class verifyLocationReplyFields {
        public static let ver = "ver"
        public static let tower_status = "tower_status"
        public static let gps_location_status = "gps_location_status"
        public static let gps_location_accuracy_km = "gps_location_accuracy_km"
    }
    
    //qosPosition fields
    class qosPositionFields {
        public static let positionid = "positionid"
        public static let gps_location = "gps_location"
    }
    
    //qosPositionKpiRequest fields
    class qosPositionKpiRequestFields {
        public static let ver = "ver"
        public static let session_cookie = "session_cookie"
        public static let positions = "positions"
    }
    
    //qosPositionKpiResult fields
    class qosPositionKpiResultFields {
        public static let positionid = "positionid"
        public static let gps_location = "gps_location"
        public static let dluserthroughput_min = "dluserthroughput_min"
        public static let dluserthroughput_avg = "dluserthroughput_avg"
        public static let dluserthroughput_max = "dluserthroughput_max"
        public static let uluserthroughput_min = "uluserthroughput_min"
        public static let uluserthroughput_avg = "uluserthroughput_avg"
        public static let uluserthroughput_max = "uluserthroughput_max"
        public static let latency_min = "latency_min"
        public static let latency_avg = "latency_avg"
        public static let latency_max = "latency_max"
    }
    
    //qosPositionKpiReply fields
    class qosPositionKpiReplyFields {
        public static let ver = "ver"
        public static let status = "status"
        public static let position_results = "position_results"
    }
}
