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
//  GetConnectionUtil.swift
//

import os.log

extension MobiledgeXiOSLibrary.MatchingEngine {

    public enum GetConnectionProtocol {
      case tcp
      case udp
      case http
      case websocket
    }
    
    public func isEdgeEnabled(proto: GetConnectionProtocol) -> EdgeError? {
        
        if (state.isUseWifiOnly()) {
            return EdgeError.wifiOnly(message: "useWifiOnly must be false to enable edge connection")
        }
        
        if (!MobiledgeXiOSLibrary.NetworkInterface.hasCellularInterface()) {
            return EdgeError.missingCellularInterface(message: "\(proto) connection requires a cellular interface to run connection over edge")
        }
        
        guard let _  = MobiledgeXiOSLibrary.NetworkInterface.getIPAddress(netInterfaceType: MobiledgeXiOSLibrary.NetworkInterface.CELLULAR) else {
            return EdgeError.missingCellularIP(message: "Unable to find ip address for local cellular interface")
        }
        
        if (proto == GetConnectionProtocol.http || proto == GetConnectionProtocol.websocket) {
            if (MobiledgeXiOSLibrary.NetworkInterface.hasWifiInterface()) {
                return EdgeError.defaultWifiInterface(message: "\(proto) connection requires wifi to be off in order to run connection over edge")
            }
        }
        
        return nil
    }
}
