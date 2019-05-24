//
//  FindCloudlet.swift
//  Pods
//
//  Copyright 2019 MobiledgeX, Inc. All rights and licenses reserved.

import Foundation
import NSLogger
import Promises

enum MatchingEngineParameterError: Error {
    case missingCarrierName
    case missingDeviceGPSLocation
}

extension MatchingEngine {
    
    public func doVerifyLocation(gpslocation: [String: AnyObject])
        -> Promise<[String: AnyObject]>?
    {
        Swift.print("Verify Location of this Mex client.")
        Swift.print("===================================\n\n")
        
        guard let tokenServerUri = state.getTokenServerUri() else {
            return nil
        }
        
        let count = tokenServerUri.count
        if count == 0
        {
            Logger.shared.log(.network, .error, "ERROR: TokenURI is empty!")
            return nil
        }
        // Bleh
        
        
        let verifyLocationFuture = self.verifyLocation(gpsLocation: gpslocation)
        return verifyLocationFuture
    }
    
    /// <#Description#>
    ///
    /// - Parameters:
    ///   - carrierName: <#carrierName description#>
    ///   - gpslocation: <#gpslocation description#>
    ///   - verifyloctoken: <#verifyloctoken description#>
    ///
    /// - Returns: API json/Dictionary
    public func createVerifyLocationRequest(_ carrierName: String,
                                            _ gpslocation: [String: Any],
                                            _ verifyloctoken: String)
        -> [String: Any] // json/Dictionary
    {
        var verifyLocationRequest = [String: Any]() // Dictionary/json
        
        verifyLocationRequest["ver"] = 1
        verifyLocationRequest["SessionCookie"] = self.state.getSessionCookie()
        verifyLocationRequest["CarrierName"] = carrierName
        verifyLocationRequest["GpsLocation"] = gpslocation
        verifyLocationRequest["VerifyLocToken"] = verifyloctoken
        
        return verifyLocationRequest
    }
    
    private func getToken(uri: String) -> Promise<String> // async
    {
        Swift.print("In Get Token, with uri: \(uri)")
        
        return Promise<String>() { fulfill, reject in
            if uri.count == 0 {
                reject(InvalidTokenServerTokenError.invalidTokenServerUri)
                return
            }
            fulfill(uri)
            }.then {tokenUri in
                self.postRequest(uri: tokenUri, request: [String: Any]())
            }.then { reply in
                guard let token = reply["VerifyLocToken"] as? String else {
                    throw InvalidTokenServerTokenError.invalidToken
                }
                return Promise(token)
        }
    }
    
    private func tokenizeRequest(carrierName: String, verifyLocationToken: String, gpsLocation: [String: AnyObject])
        throws
        -> [String: Any] {
            
        if (verifyLocationToken.count > 0) {
            throw InvalidTokenServerTokenError.invalidToken
        }
        
        let verifyLocationRequest = self.createVerifyLocationRequest(carrierName, gpsLocation, "")
        var tokenizedRequest = [String: Any]() // Dictionary/json
        tokenizedRequest += verifyLocationRequest
        tokenizedRequest["VerifyLocToken"] = verifyLocationToken
        return tokenizedRequest
    }
    
    // TODO: This should be paramaterized:
    public func verifyLocation(gpsLocation: [String: Any]) -> Promise<[String: AnyObject]> {
        
        // Dummy promise to check inputs:
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()
        guard let carrierName = self.state.carrierName else {
            promiseInputs.reject(MatchingEngineParameterError.missingCarrierName)
            return promiseInputs
            
        }
        guard let gpsLoc = self.state.deviceGpsLocation else {
            promiseInputs.reject(MatchingEngineParameterError.missingDeviceGPSLocation)
            return promiseInputs
        }
        guard let tokenServerUri = self.state.getTokenServerUri() else {
            promiseInputs.reject(InvalidTokenServerTokenError.invalidTokenServerUri)
            return promiseInputs
        }
        
         // This doesn't catch anything. It does throw errors to the caller.
        return self.getToken(uri: tokenServerUri).then(on: self.executionQueue) { verifyLocationToken in

            let baseuri = MexUtil.shared.generateBaseUri(carrierName, MexUtil.shared.dmePort)
            let verifylocationAPI: String = MexUtil.shared.verifylocationAPI
            let uri = baseuri + verifylocationAPI
            
            return self.postRequest(
                uri: uri,
                request: try self.tokenizeRequest(
                    carrierName: carrierName,
                    verifyLocationToken: verifyLocationToken,
                    gpsLocation: gpsLoc))
        } // End return.
    }
}
