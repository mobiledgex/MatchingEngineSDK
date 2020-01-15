//
//  MatchingEngineErrors.swift
//  MobiledgeXSDK
//
//  Created by Franlin Huang on 1/14/20.
//

import Foundation

extension MobiledgeXSDK.MatchingEngine {
    
    public enum MatchingEngineError: Error {
        case networkFailure
        case missingAppName
        case missingAppVersion
        case missingDevName
        case missingCarrierName
        case missingSessionCookie
        
        case missingGPSLocation
        case invalidGPSLongitude
        case invalidGPSLatitude
        
        case missingTokenServerURI
        case missingTokenServerToken
        case missingGPSLocationStatus
        case registerFailed
        case findCloudletFailed
        case verifyLocationFailed
    }
    
    public enum InvalidTokenServerTokenError: Error  {
        case invalidTokenServerUri
        case cannotContactServer
        case invalidToken
        case invalidTokenServerResponse
    }
}
