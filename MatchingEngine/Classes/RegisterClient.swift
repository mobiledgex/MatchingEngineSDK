//
//  RegisterClient.swift
//  Pods
//
//  Copyright 2019 MobiledgeX, Inc. All rights and licenses reserved.

import Foundation
import NSLogger
import Promises

// MARK: RegisterClient code.

// GCD based FutureX code dependencies.

extension MatchingEngine
{
    // MARK:
    
    // Sets: sessioncookie, tokenserveruri
    
    func registerClientResult(_ registerClientReply: [String: Any])
    {
        if registerClientReply.count == 0
        {
            Swift.print("REST RegisterClient Error: NO RESPONSE.")
        }
        else
        {
            let line1 = "\nREST RegisterClient Status: \n"
            let line2 = "Version: " + (registerClientReply["Ver"] as? String ?? "0")
            let line3 = ",\n Client Status:" + (registerClientReply["Status"] as? String ?? "")
            let line4 = ",\n SessionCookie:" + (registerClientReply["SessionCookie"] as? String ?? "")
            
            Swift.print(line1 + line2 + line3 + line4 + "\n\n")
            Swift.print("Token Server URI: " + (registerClientReply["TokenServerURI"] as? String ?? "") + "\n")
        }
    }
    
    /// API createRegisterClientRequest
    ///
    /// - Parameters:
    ///   - ver: "1"
    ///   - appName: "appName"
    ///   - devName:  "devName"
    ///   - appVers: "appVers""
    /// - Returns: API Dictionary/json
    func createRegisterClientRequest(appName: String, devName: String, appVers: String)
        -> [String: Any] // Dictionary/json
    {
        var regClientRequest = [String: String]() // Dictionary/json regClientRequest
        
        regClientRequest["ver"] = "1"
        regClientRequest["AppName"] = appName
        regClientRequest["DevName"] = devName
        regClientRequest["AppVers"] = appVers
        
        return regClientRequest
    }

    public func registerClient(appName: String, devName: String,  appVers: String)
        -> Promise<[String: AnyObject]>
    {
        guard let carrierName = getCarrierName() else { // FIXME: Handle multiple carriers.
            let promise = Promise<[String: AnyObject]> { fulfill, reject in
                reject(MatchingEngineError.missingCarrierName)
            }
            return promise
        }
        
        return registerClient(carrierName: carrierName, appName: appName, devName: devName, appVers: appVers)
    }
    
    public func registerClient(carrierName: String, appName: String, devName: String,  appVers: String)
        -> Promise<[String: AnyObject]>
    {
        Logger.shared.log(.network, .debug, "registerClient")
        
        let baseuri = MexUtil.shared.generateBaseUri(carrierName, MexUtil.shared.dmePort)
        Logger.shared.log(.network, .debug, "\(baseuri)")
        
        // 🔵 API
        let registerClientRequest = createRegisterClientRequest(appName:appName, devName: devName, appVers: appVers)
        let urlStr = baseuri + MexUtil.shared.registerAPI
        
        // Return a promise:
        return self.postRequest(uri: urlStr, request: registerClientRequest).then { replyDict in
            guard let sessionCookie = replyDict["SessionCookie"] as? String else {
                self.state.setSessionCookie(sessionCookie: nil);
                return Promise<[String: AnyObject]>.pending().reject(MatchingEngineError.missingSessionCookie)
            }
            self.state.setSessionCookie(sessionCookie: sessionCookie)
            Logger.shared.log(.network, .debug, " saved sessioncookie")
            
            guard let tokenServerUri = replyDict["TokenServerURI"] as? String else {
                self.state.setTokenServerUri(tokenServerUri: nil);
                return Promise<[String: AnyObject]>.pending().reject(MatchingEngineError.missingTokenServerURI)
            }
            self.state.setTokenServerUri(tokenServerUri: tokenServerUri)
            Logger.shared.log(.network, .debug, " saved tokenserveruri\n")
            
            // Implicit return replyDict.
        }
    }
       
} // end RegisterClient
