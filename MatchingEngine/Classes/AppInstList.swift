//
//  AppInstList.swift
//  Pods
//
//  Copyright 2019 MobiledgeX, Inc. All rights and licenses reserved.

import Foundation
import NSLogger
import Promises

extension MatchingEngine {
    /// createGetAppInstListRequest
    ///
    /// - Parameters:
    ///   - carrierName: <#carrierName description#>   // Carrier name can change depending on cell tower.
    ///   - gpslocation: <#gpslocation description#>
    ///
    /// - Returns: API Dictionary/json
    
    public func createGetAppInstListRequest(carrierName: String, gpslocation: [String: Any]) -> [String: Any]
    {
        //   json findCloudletRequest;
        var appInstListRequest = [String: Any]() // Dictionary/json
        
        appInstListRequest["vers"] = 1
        appInstListRequest["SessionCookie"] = state.getSessionCookie()
        appInstListRequest["CarrierName"] = carrierName
        appInstListRequest["GpsLocation"] = gpslocation
        
        return appInstListRequest
    }
    
    public func getAppInstList(gpslocation: [String: Any]) // called by top right menu
        -> Promise<[String: AnyObject]>
    {
        Swift.print("GetAppInstList")
        Swift.print(" MEX client.")
        Swift.print("====================\n")
        
        let baseuri = MexUtil.shared.generateBaseUri(MexUtil.shared.getCarrierName(), MexUtil.shared.dmePort)
        Swift.print("\(baseuri)")
        
        let urlStr = baseuri + MexUtil.shared.appinstlistAPI

        
        let getAppInstListRequest = createGetAppInstListRequest(
            carrierName: MexUtil.shared.carrierNameDefault_TDG, // FIXME
            gpslocation: gpslocation
        )
        
        return self.postRequest(uri: urlStr, request: getAppInstListRequest)
        .then { replyDict in
            Logger.shared.log(.network, .debug, "AppInstList Reply: \(replyDict)")
        }

    }
}
