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
    
    public func doVerifyLocation(gpsLocation: [String: AnyObject])
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
        
        let verifyLocRequest = createVerifyLocationRequest(carrierName: getCarrierName(), gpsLocation: gpsLocation)
        return self.verifyLocation(request: verifyLocRequest)
    }
    
    /// <#Description#>
    ///
    /// - Parameters:
    ///   - carrierName: <#carrierName description#>
    ///   - gpslocation: <#gpslocation description#>
    ///   - verifyloctoken: <#verifyloctoken description#>
    ///
    /// - Returns: API json/Dictionary
    public func createVerifyLocationRequest(carrierName: String?,
                                            gpsLocation: [String: Any])
        -> [String: Any] // json/Dictionary
    {
        var verifyLocationRequest = [String: Any]() // Dictionary/json
        
        verifyLocationRequest["ver"] = 1
        verifyLocationRequest["SessionCookie"] = self.state.getSessionCookie()
        verifyLocationRequest["CarrierName"] = carrierName ?? state.carrierName
        verifyLocationRequest["GpsLocation"] = gpsLocation

        return verifyLocationRequest
    }
    
    func validateVerifyLocationRequest(request: [String: Any]) throws
    {
        guard let _ = request["SessionCookie"] as? String else {
            throw MatchingEngineError.missingSessionCookie
        }
        guard let _ = request["CarrierName"] as? String else {
            throw MatchingEngineError.missingCarrierName
        }
        guard let gpsLocation = request["GpsLocation"] as? [String: Any] else {
            throw MatchingEngineError.missingGPSLocation
        }
        let _ = try validateGpsLocation(gpsLocation: gpsLocation)
        
        guard let _ = request["VerifyLocToken"] as? String else {
            throw MatchingEngineError.missingTokenServerToken
        }
    }
    
    private func getToken(uri: String) -> Promise<String> // async
    {
        Logger.shared.log(.network, .debug, "In Get Token, with uri: \(uri)")
        
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
        throws -> [String: Any]
    {
            
        if (verifyLocationToken.count > 0) {
            throw InvalidTokenServerTokenError.invalidToken
        }
        
        let verifyLocationRequest = self.createVerifyLocationRequest(carrierName: carrierName, gpsLocation: gpsLocation)
        var tokenizedRequest = [String: Any]() // Dictionary/json
        tokenizedRequest += verifyLocationRequest
        tokenizedRequest["VerifyLocToken"] = verifyLocationToken
            
        return tokenizedRequest
    }
    
    public func verifyLocation(request: [String: Any]) -> Promise<[String: AnyObject]> {
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()
        
        guard let carrierName = state.carrierName ?? getCarrierName() else {
            Logger.shared.log(.network, .info, "MatchingEngine is unable to retrieve a carrierName to create a network request.")
            promiseInputs.reject(MatchingEngineError.missingCarrierName)
            return promiseInputs
        }
        
        let host = MexUtil.shared.generateDmeHost(carrierName: carrierName)
        let port = state.defaultRestDmePort
        
        return verifyLocation(host: host, port: port, request: request)
    }
    
    // TODO: This should be paramaterized:
    public func verifyLocation(host: String, port: UInt, request: [String: Any]) -> Promise<[String: AnyObject]> {
        
        // Dummy promise to check inputs:
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()

        guard let carrierName = self.state.carrierName ?? getCarrierName() else {
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

            let baseuri = MexUtil.shared.generateBaseUri(host: host, port: port)
            let verifylocationAPI: String = MexUtil.shared.verifylocationAPI
            let uri = baseuri + verifylocationAPI
            
            if (verifyLocationToken.count > 0) {
                throw InvalidTokenServerTokenError.invalidToken
            }
            
            // Append Token
            var tokenizedRequest = [String: Any]() // Dictionary/json
            tokenizedRequest += request
            tokenizedRequest["VerifyLocToken"] = verifyLocationToken
            try self.validateVerifyLocationRequest(request: request)
            
            return self.postRequest(uri: uri,
                                    request: tokenizedRequest)
        } // End return.
    }
}
