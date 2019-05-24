//
//  FindCloudlet.swift
//  Pods
//
//  Copyright 2019 MobiledgeX, Inc. All rights and licenses reserved.

import Foundation
import NSLogger
import Promises

extension MatchingEngine {
    // Carrier name can change depending on cell tower.
    //
    
    /// createFindCloudletRequest
    ///
    /// - Parameters:
    ///   - carrierName: <#carrierName description#>
    ///   - gpslocation: <#gpslocation description#>
    /// - Returns: API  Dictionary/json
    
    // Carrier name can change depending on cell tower.
    func createFindCloudletRequest(_ carrierName: String, _ gpslocation: [String: Any]) -> [String: Any]
    {
        //    findCloudletRequest;
        var findCloudletRequest = [String: Any]() // Dictionary/json
        
        findCloudletRequest["vers"] = 1
        findCloudletRequest["SessionCookie"] = self.state.getSessionCookie()
        findCloudletRequest["CarrierName"] = carrierName
        findCloudletRequest["GpsLocation"] = gpslocation
        
        return findCloudletRequest
    }
    
    // TODO: overload findCloudlet to take more parameters, add platformIntegrtion.swift.
    
    public func findCloudlet(gpslocation: [String: Any])
        -> Promise<[String: AnyObject]>//   called by top right menu
    {
        Swift.print("Finding nearest Cloudlet appInsts matching this Mex client.")
        Swift.print("===========================================================")
        
        for i in 0...10 {
            print("Delay: \(i)")
            sleep(1)
        }
        
        let baseuri = MexUtil.shared.generateBaseUri(MexUtil.shared.getCarrierName(), MexUtil.shared.dmePort)
        let findCloudletRequest = self.createFindCloudletRequest(MexUtil.shared.carrierNameDefault_TDG, gpslocation)
        let urlStr = baseuri + MexUtil.shared.findcloudletAPI
        
        // postRequest is dispatched to background by default:
        return self.postRequest(uri: urlStr, request: findCloudletRequest)
    }
    
}
