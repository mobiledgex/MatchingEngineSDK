//
//  FindCloudlet.swift
//  Pods
//
//  Copyright 2019 MobiledgeX, Inc. All rights and licenses reserved.

import Foundation
import NSLogger
import Alamofire
import Promises

enum MatchingEngineParameterError: Error {
    case missingCarrierName
    case missingDeviceGPSLocation
}

//VerifyLocationRequest fields
class VerifyLocationRequest {
    public static let ver = "ver"
    public static let session_cookie = "session_cookie"
    public static let carrier_name = "carrier_name"
    public static let gps_location = "gps_location"
    public static let verify_loc_token = "verify_loc_token"
}

//VerifyLocationReply fields
class VerifyLocationReply {
    public static let ver = "ver"
    public static let tower_status = "tower_status"
    public static let gps_location_status = "gps_location_status"
    public static let gps_location_accuracy_km = "gps_location_accuracy_km"
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
        
        verifyLocationRequest[VerifyLocationRequest.ver] = 1
        verifyLocationRequest[VerifyLocationRequest.session_cookie] = self.state.getSessionCookie()
        verifyLocationRequest[VerifyLocationRequest.carrier_name] = carrierName ?? state.carrierName
        verifyLocationRequest[VerifyLocationRequest.gps_location] = gpsLocation

        return verifyLocationRequest
    }
    
    func validateVerifyLocationRequest(request: [String: Any]) throws
    {
        guard let _ = request[VerifyLocationRequest.session_cookie] as? String else {
            throw MatchingEngineError.missingSessionCookie
        }
        guard let _ = request[VerifyLocationRequest.carrier_name] as? String else {
            throw MatchingEngineError.missingCarrierName
        }
        guard let gpsLocation = request[VerifyLocationRequest.gps_location] as? [String: Any] else {
            throw MatchingEngineError.missingGPSLocation
        }
        let _ = try validateGpsLocation(gpsLocation: gpsLocation)
        
        guard let _ = request[VerifyLocationRequest.verify_loc_token] as? String else {
            throw MatchingEngineError.missingTokenServerToken
        }
    }
    
    // Special version of postRequest. 303 is an error.
    private func getTokenPost(uri: String) // Dictionary/json
        -> Promise<[String: AnyObject]>
    {
        Logger.shared.log(.network, .debug, "uri: \(uri) request\n")
        
        return Promise<[String: AnyObject]>(on: self.executionQueue) { fulfill, reject in
            
            // The value is returned via reslove/reject.
            let _ = self.sessionManager!.request(
                uri,
                method: .post,
                parameters: [String: Any](),
                encoding: JSONEncoding.default,
                headers: self.headers
            ).responseJSON { response in
                Logger.shared.log(.network, .debug, "\n••\n\(response.request!)\n")
                
                // 303 SeeOther is "ServerName Not found", which is odd
                guard let _ = response.result.error else {
                    // This is unexpected in AlamoFire.
                    reject(InvalidTokenServerTokenError.invalidTokenServerResponse)
                    return
                }
                
                // Very strange HTTP handling in Alamofire. No headers. Not nice.
                Logger.shared.log(.network, .debug, "Expected Error. Handling token.")
                if !response.result.isSuccess
                {
                    let msg = String(describing: response.result.error)
                    Logger.shared.log(.network, .debug, "msg: \(msg)")
                    if msg.contains("dt-id=")
                    { // not really an error
                        let dtId = msg.components(separatedBy: "dt-id=")
                        let s1 = dtId[1].components(separatedBy: ",")
                        let token = s1[0]
                        Logger.shared.log(.network, .debug, "\(token)")
                        fulfill(["token": token as AnyObject])
                    } else {
                        // Missing token.
                        reject(InvalidTokenServerTokenError.invalidTokenServerResponse)
                    }
                }
                else
                {
                    // Should not succeed on 303.
                    reject(InvalidTokenServerTokenError.invalidTokenServerResponse)
                }
            }
        }
    }
    
    private func getTokenPost3(uri: String) // Dictionary/json
        -> Promise<[String: AnyObject]>
    {
        Logger.shared.log(.network, .debug, "uri: \(uri) request\n")
        
        return Promise<[String: AnyObject]>(on: self.executionQueue) { fulfill, reject in
            let url = URL(string: uri)
            var urlRequest = URLRequest(url: url!)
            
            let request = [String: Any]()
            let jsonRequest = try JSONSerialization.data(withJSONObject: request)
            urlRequest.httpBody = jsonRequest
            urlRequest.httpMethod = "POST"
            urlRequest.allHTTPHeaderFields = self.headers
            urlRequest.allowsCellularAccess = true
            
            Swift.print("URL request get token is ")
            Swift.print(urlRequest)
            
            let session = URLSession.init(configuration: URLSessionConfiguration.default, delegate: SessionDelegate(), delegateQueue: OperationQueue.main)

            Swift.print("before")
            let dataTask = session.dataTask(with: urlRequest as URLRequest) { (data, response, error) in
                Swift.print("inside")
                if (error != nil) {
                    reject(InvalidTokenServerTokenError.invalidTokenServerResponse)
                } else {
                    guard let httpResponse = response as? HTTPURLResponse else {
                        Logger.shared.log(.network, .debug, "Cant cast response at HTTPURLResponse")
                        return
                    }
                    if let location = httpResponse.allHeaderFields["Location"] as? String {
                        if location.contains("dt-id=") {
                            let dtId = location.components(separatedBy: "dt-id=")
                            let s1 = dtId[1].components(separatedBy: ",")
                            let token = s1[0]
                            Logger.shared.log(.network, .debug, "\(token)")
                            Swift.print("Token is ")
                            Swift.print(token)
                            fulfill(["token": token as AnyObject])
                        } else {
                            Logger.shared.log(.network, .debug, "Invalid token response \(location)")
                            reject(InvalidTokenServerTokenError.invalidTokenServerResponse)
                        }
                    }
                }
            }
            dataTask.resume()
        }
    }

    public class SessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
        
        //var completionHandler:((URLResponse, NSError, Data) -> Promise<[String: AnyObject]>)?

        public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void)
        {
            Swift.print("Repsonse in cancel is ")
            Swift.print(response)
            completionHandler(nil)
        }
        
        public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
        {
            var mimeType: String? = nil
            var headers: [NSObject : AnyObject]? = nil
            
            // Ignore NSURLErrorCancelled errors - these are a result of us cancelling the session in
            // the delegate method URLSession(session:dataTask:response:completionHandler:).
            //if (error == nil || error?.localizedDescription == NSURLErrorCancelled) {
            Swift.print("Localized descript of error is")
            Swift.print(error?.localizedDescription)
                
                mimeType = task.response?.mimeType
                
                if let httpStatusCode = (task.response as? HTTPURLResponse)?.statusCode {
                    headers = (task.response as? HTTPURLResponse)?.allHeaderFields as [NSObject : AnyObject]?
                    
                    if httpStatusCode >= 200 && httpStatusCode < 300 {
                        // All good
                        Swift.print("YUUUUHHHH")
                        
                    } else {
                        // You may want to invalidate the mimeType/headers here as an http error
                        // occurred so the mimeType may actually be for a 404 page or
                        // other resource, rather than the URL you originally requested!
                        // mimeType = nil
                        // headers = nil
                        Swift.print("HTTP STATUS NOT GOOD")
                    }
                }
            //}
            
            Swift.print("mimeType = \(String(describing: mimeType))")
            Swift.print("headers = \(String(describing: headers))")
            
            session.invalidateAndCancel()
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
        }.then { tokenUri in
                self.getTokenPost3(uri: tokenUri)
        }.then { reply in
            guard let token = reply["token"] as? String else {
                return Promise("")
            }
            return Promise(token)
        }
    }
    
    private func tokenizeRequest(carrierName: String, verifyLocationToken: String, gpsLocation: [String: AnyObject])
        throws -> [String: Any]
    {
            
        if (verifyLocationToken.count == 0) {
            throw InvalidTokenServerTokenError.invalidToken
        }
        
        let verifyLocationRequest = self.createVerifyLocationRequest(carrierName: carrierName, gpsLocation: gpsLocation)
        var tokenizedRequest = [String: Any]() // Dictionary/json
        tokenizedRequest += verifyLocationRequest
        tokenizedRequest[VerifyLocationRequest.verify_loc_token] = verifyLocationToken
            
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
    public func verifyLocation(host: String, port: UInt, request: [String: Any]) -> Promise<[String: AnyObject]>
    {
        
        // Dummy promise to check inputs:
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()

        guard let _ = request[VerifyLocationRequest.carrier_name] ?? self.state.carrierName ?? getCarrierName() else {
            promiseInputs.reject(MatchingEngineParameterError.missingCarrierName)
            return promiseInputs
        }
        guard let _ = request[VerifyLocationRequest.gps_location] ?? self.state.deviceGpsLocation else {
            promiseInputs.reject(MatchingEngineParameterError.missingDeviceGPSLocation)
            return promiseInputs
        }
        
        // mini-check server uri to get token:
        guard let tokenServerUri = self.state.getTokenServerUri() else {
            promiseInputs.reject(InvalidTokenServerTokenError.invalidTokenServerUri)
            return promiseInputs
        }
        
         // This doesn't catch anything. It does throw errors to the caller.
        return self.getToken(uri: tokenServerUri).then(on: self.executionQueue) { verifyLocationToken in

            let baseuri = MexUtil.shared.generateBaseUri(host: host, port: port)
            let verifylocationAPI: String = MexUtil.shared.verifylocationAPI
            let uri = baseuri + verifylocationAPI
            
            if (verifyLocationToken.count == 0) {
                throw InvalidTokenServerTokenError.invalidToken
            }
            
            // Append Token
            var tokenizedRequest = request // Dictionary/json
            tokenizedRequest[VerifyLocationRequest.verify_loc_token] = verifyLocationToken
            try self.validateVerifyLocationRequest(request: tokenizedRequest)
            
            return self.postRequest(uri: uri,
                                    request: tokenizedRequest)
        } // End return.
    }
}
