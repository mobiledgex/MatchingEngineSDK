// Sample Client of SDK
//
//  Sample_client.swift
//  SkeletonApp
//
// Copyright 2019 MobiledgeX
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import CoreLocation
import MapKit
import Security
import UIKit

import Alamofire
import GoogleMaps

import SwiftLocation

import NSLogger
import Promises
import MatchingEngine

// ----------------------------------------
//
private var locationRequest: LocationRequest? // so we can stop updates

// --------
// face servers
//
private let faceServerPort: String = "8008"

private let DEF_FACE_HOST_CLOUD = "facedetection.defaultcloud.mobiledgex.net"
private let DEF_FACE_HOST_EDGE = "facedetection.defaultedge.mobiledgex.net"

public class LocationColorCode
{
    public static let NEUTRAL: UInt32 = 0xFF67_6798 // default
    public static let VERIFIED: UInt32 = 0xFF00_9933
    public static let FAILURE: UInt32 = 0xFFFF_3300
    public static let CAUTION: UInt32 = 0xFF00_B33C // Amber: ffbf00;
}


// --------

// This file Handles Events from:
//  Menu:
//  "Register Client",  // these first two are done actomicaly at launch
//  "Get App Instances",    // displays network POIs on map
//
//  "Verify Location",      // visual feedback: gray, green, failed: red
//  "Find Closest Cloudlet",    // animate Closest Cloudlet to center
//  "Reset Location",   // animate userMarker back to its gps location



// MARK: -
func processAppInstList(_ d: [String: Any] )
{
    Swift.print("GetAppInstlist1 \(d)")
    
    //  theMap!.clear()
    
    var cloudlets = [String: Cloudlet]()
    Swift.print("~~~~~")
    
    var boundsBuilder = GMSCoordinateBounds()
    
    var marker: GMSMarker?
    
    for (index, cld) in d.enumerated()
    {
        Swift.print("\n•\n \(index):\(cld)")
        
        Swift.print("\(index): \(cld.key)")
        
        if cld.key == "Cloudlets" // "cloudlet_location"
        {
            let a = cld.value as! [[String: Any]]   // Dictionary/json
            
            Swift.print("••• \(a)")
            
            for d in a
            {
                // ["CarrierName", "CloudletName", "GpsLocation", "Distance", "Appinstances"]
                
                Swift.print("\(Array(d.keys))")
                let gps = d["GpsLocation"] as! [String: Any] // "cloudlet_location"
                
                // let gps = cld.value as! [String:Any]
                Swift.print("\(gps)")
                
                let loc = CLLocationCoordinate2D(
                    latitude: Double((gps["latitude"] as! NSNumber).stringValue)!,
                    longitude: Double((gps["longitude"] as! NSNumber).stringValue)!
                )
                Swift.print("\(loc)")
                
                Swift.print("\(Array(d.keys))\n")
                Swift.print("d ••••• \(d)")
                
                let dd = d["Appinstances"] as! [[String: Any]]  // Dictionary/json
                let uri = dd[0]["FQDN"] as! String // todo, now just use first
                let appName = dd[0]["AppName"] as! String
                
                let ports =  dd[0]["ports"] as! [[String: Any]]
                Swift.print("ports \(ports)")
                let portsDic = ports[0]
                
                let theFQDN_prefix = portsDic["FQDN_prefix"] as! String
                
                
                Swift.print("cloudlet uri: \(uri)")
                Swift.print("dd \(dd)")
                
                let carrierName = d["CarrierName"] as! String
                let cloudletName = d["CloudletName"] as! String
                let distance = d["Distance"] as! Double
                
                boundsBuilder = boundsBuilder.includingCoordinate(loc)
                
                marker = GMSMarker(position: loc)
                marker!.userData = cloudletName
                marker!.title = cloudletName
                marker!.snippet = "Tap for details"
                
                let iconTemplate = UIImage(named: "ic_marker_cloudlet-web")
                
                // todo refactor - make func
                let tint = getColorByHex(LocationColorCode.NEUTRAL)
                let tinted = iconTemplate!.imageWithColor(tint)
                let resized = tinted.imageResize(sizeChange: CGSize(width: 40, height: 30))
                
                let i2 = textToImage(drawText: "M", inImage: resized, atPoint: CGPoint(x: 11, y: 4))
                
                marker?.icon = (cloudletName.contains("microsoft") || cloudletName.contains("azure") || carrierName.contains("azure")) ? i2 : resized
                
                //                        init(_ cloudletName: String,
                //                        _ appName: String,
                //                        _ carrierName: String,
                //                        _ gpsLocation: CLLocationCoordinate2D ,
                //                        _ distance: Double,
                //                        _ uri: String,
                //                        _ marker: GMSMarker,
                //                        _ numBytes: Int,
                //                        _ numPackets: Int) // LatLng
                
                Swift.print("Cloudlet: \(cloudletName), \(appName), \(carrierName), \(loc),\n \(uri)")
                let cloudlet = Cloudlet(cloudletName, appName, carrierName,
                                        loc,
                                        distance,
                                        uri,
                                        theFQDN_prefix,
                    marker!,
                    1_048_576,  // actually uses setting alue at run time
                    0)
                
                marker?.map = theMap
                cloudlets[cloudletName] = cloudlet
            }
        }
    }
    Swift.print("~~~~~]\n\(cloudlets)")
    
    CloudletListHolder.getSingleton().setCloudlets(mCloudlets: cloudlets)
    
    if !(boundsBuilder.southWest == boundsBuilder.northEast)
    {
        Swift.print("Using cloudlet boundaries")
        let padding: CGFloat  = 70.0 // offset from edges of the map in pixels
        
        
        theMap!.animate(with: .fit(boundsBuilder, withPadding: padding))
    }
    else
    {
        Swift.print("No cloudlets. Don't zoom in")
    }
}


func makeUserMakerImage(_ color: UInt32) -> UIImage
{
    let iconTemplate = UIImage(named: "ic_marker_mobile-web")
    let tint = getColorByHex(color)
    let tinted = iconTemplate!.imageWithColor(tint)
    let resized = tinted.imageResize(sizeChange: CGSize(width: 60, height: 60))

    return resized
}


// MARK: -

private func useCloudlets(_ findCloudletReply: [String: Any]) // unused
{
    if findCloudletReply.count == 0
    {
        Swift.print("REST VerifyLocation Status: NO RESPONSE")
    }
    else
    {
        //            cout << "REST FindCloudlet Status: "
        //                 << "Version: " << findCloudletReply["ver"]
        //                 << ", Location Found Status: " << findCloudletReply["status"]
        //                 << ", Location of cloudlet. Latitude: " << findCloudletReply["cloudlet_location"]["lat"]
        //                 << ", Longitude: " << findCloudletReply["cloudlet_location"]["long"]
        //                 << ", Cloudlet FQDN: " << findCloudletReply["fqdn"] << endl;

        let loooc = findCloudletReply["cloudlet_location"] as! [String: Any]
        let latN = loooc["lat"] as? NSNumber // ZZZ
        let lat = "\(latN!)"
        let longN = loooc["long"] as? NSNumber
        let long = "\(longN!)"

        let line1 = "REST FindCloudlet Status: \n"
        let ver = findCloudletReply["ver"] as? NSNumber
        let line2 = "Version: " + "\(ver!)\n"
        let line3 = ", Location Found Status: " + (findCloudletReply["status"] as! String) + "\n"
        let line4 = ", Location of cloudlet. Latitude: " + lat + "\n"
        let line5 = ", Longitude: " + long + "\n"
        Swift.print("\(findCloudletReply["FQDN"]!)")
        let line6 = ", Cloudlet FQDN: " + (findCloudletReply["FQDN"] as! String ) + "\n"

        Swift.print(line1 + line2 + line3 + line4 + line5 + line6)
        let ports: [[String: Any]] = findCloudletReply["ports"] as! [[String: Any]]
        
       // let size = ports.count // size_t
        for appPort in ports
        {
            Swift.print("\(appPort)")
            //  let ap = appPort as [String:Any]
            //                cout << ", AppPort: Protocol: " << appPort["proto"]
            //                     << ", AppPort: Internal Port: " << appPort["internal_port"]
            //                     << ", AppPort: Public Port: " << appPort["public_port"]
            //                     << ", AppPort: Public Path: " << appPort["public_path"]
            //                     << endl;
            //
            //                let proto = appPort["proto"]
            //                let internal_port = appPort["internal_port"]
            //
            //                let public_port = appPort["public_port"]
            //                let public_path = appPort["public_path"]
            //
            //                Swift.print(", AppPort: Protocol: \(proto)" +
            //                ", AppPort: Internal Port: \(internal_port)" +
            //                    ", AppPort: Internal Port: \(public_port)" +
            //                    ", AppPort: ublic Path:  \(public_path)"

            //                )
        }
    }
}

// MARK: -


/**
 * This makes a web service call to the location simulator to update the current IP address
 * entry in the database with the given latitude/longitude.
 *
 * @param lat
 * @param lng
 */
public func updateLocSimLocation(hostName: String, latitude: Double, longitude: Double)
{
    // Swift.print("\(#function)")

    let jd: [String: Any]? = ["latitude": latitude, "longitude": longitude]    // Dictionary/json
    let urlString: URLConvertible = "http://\(hostName):8888/updateLocation"

    Swift.print("\(urlString)")

    Alamofire.request( urlString,
                      method: HTTPMethod.post,
                      parameters: jd,
                      encoding: JSONEncoding.default)
        .responseString
    { response in
        Swift.print("----\n")
        Swift.print("\(response)")
        //     debugPrint(response)

        switch response.result {
        case .success:
            //      debugPrint(response)
            SKToast.show(withMessage: "UpdateLocSimLocation result: \(response)")

        case let .failure(error):
            print(error)
            SKToast.show(withMessage: "UpdateLocSimLocation Failed: \(error)")
        }
    }
}



func processFindCloudletResult(_ d: [String: Any])
{
    // Swift.print("\(#function)")

    for (index, cld) in d.enumerated()
    {
        Swift.print("\n•\n \(index):\(cld)")
        
        //                init(_ cloudletName: String,
        //                _ appName: String,
        //                _ carrierName: String,
        //                _ gpsLocation: CLLocationCoordinate2D ,
        //                _ distance: Double,
        //                _ uri: String,
        //                _ marker: GMSMarker,
        //                _ numBytes: Int,
        //                _ numPackets: Int) // LatLng
        
        //                 if index == 0
        //                 {
        //                    uri = cld.value as! String
        //                }
        Swift.print("\(index): \(cld.key)")
        
        if cld.key == "FQDN"
        {
            let v = cld.value
            Swift.print("•FQDN• \(v)")
            
            MexUtil.shared.closestCloudlet = v as! String
            
            Swift.print("")
        }
        
        if cld.key == "cloudlet_location"
        {
            let dd = cld.value as! [String: Any] // Dictionary/json
            
            Swift.print("••• \(dd)")
            
            let loc = CLLocationCoordinate2D(
                latitude: Double((dd["latitude"] as! NSNumber).stringValue)!,
                longitude: Double((dd["longitude"] as! NSNumber).stringValue)!
            )
            
            theMap!.animate(toLocation: loc)
            SKToast.show(withMessage: "Found cloest cloudlet")
            
            // break
        }
    }
}

// MARK: -
// MARK: resetUserLocation

func resetUserLocation(_ show: Bool) // called by "Reset user location" menu
{
    // Swift.print("\(#function)")
    locationRequest = Locator.subscribePosition(accuracy: .house, onUpdate:
        { newLocation in
            // print("New location received: \(newLocation)")
            if userMarker == nil
            {
                doUserMarker(newLocation.coordinate)
            }
            userMarker!.position = newLocation.coordinate
            
            DispatchQueue.main.async
                {
                    stopGPS()
            }
            
            if show
            {
                theMap!.animate(toLocation: userMarker!.position)
            }
            
    }, onFail: { err, _ in
        print("subscribePosition: Failed with error: \(err)")
    })
}

private func stopGPS()
{
    Locator.stopRequest(locationRequest!)
}


func doUserMarker(_ loc: CLLocationCoordinate2D)
{
    // Swift.print("\(#function)")

    // requestWhenInUseAuthorization()
    
    userMarker = GMSMarker(position: loc)
    userMarker!.title = "You are here"
    userMarker!.snippet = "Drag to spoof" //   marker!.snippet = "Tap for details"
    
    let resized =  makeUserMakerImage(LocationColorCode.NEUTRAL)
    
    userMarker!.icon = resized
    userMarker!.map = theMap
    
    userMarker!.isDraggable = true // drag to test spoofing
}

// MARK: -
// used by: GetToken, getAppInstNow, verify  loc
 public func retrieveLocation() -> [String: Any]
{
    // Swift.print("\(#function)")

    var location:[String: Any] = [ "latitude": -122.149349, "longitude": 37.459609] //     //  json location, somewhere

    if userMarker != nil // get app isnt sets userMarker
    {
        location["latitude"] = userMarker!.position.latitude
        location["longitude"] = userMarker!.position.longitude
    }

    return location
}

// MARK: -
public var faceRecognitionImages2 =  [(UIImage,String)]()  // image + service. one at a time

class MexFaceRecognition
{
    var faceDetectionStartTimes:[String:DispatchTime]? // two at a time cloud/edge
    var faceRecognitionStartTimes:[String:DispatchTime]? // two at a time cloud/edge

   var faceRecognitionCurrentImage: UIImage?
    
    // Mark: -
    // Mark: FaceDetection
    
    func FaceDetection(_ image: UIImage?, _ service: String)
        -> Promise<[String: AnyObject]>
    {
        // Swift.print("\(#function)")

        let broadcast =  "FaceDetectionLatency" + service
        
        let faceDetectionFuture = FaceDetectionCore(image, service, post: broadcast)
        
        return faceDetectionFuture
    }
    
    //  todo? pass in host
    
    func FaceDetectionCore(_ image: UIImage?,  _ service: String, post broardcastMsg: String?)
        -> Promise<[String: AnyObject]>
    {
        // Swift.print("\(#function)")
        
        let promise = Promise<[String: AnyObject]>.pending()
        
        // detector/detect
        // Used to send a face image to the server and get back a set of coordinates for any detected faces.
        // POST http://<hostname>:8008/detector/detect/
        
        let faceDetectionAPI: String = "/detector/detect/"
        
        //    Swift.print("FaceDetection")
        //    Swift.print("FaceDetection MEX .")
        //    Swift.print("====================\n")
        //
        
        getNetworkLatency(DEF_FACE_HOST_EDGE, post: "updateNetworkLatenciesEdge")
        getNetworkLatency(DEF_FACE_HOST_CLOUD, post: "updateNetworkLatenciesCloud")  //
        
        let _ = GetSocketLatency( DEF_FACE_HOST_CLOUD, Int32(faceServerPort)!, "latencyCloud")   //
        
        let baseuri = (service == "Cloud" ? DEF_FACE_HOST_CLOUD  : DEF_FACE_HOST_EDGE) + ":" + faceServerPort
        
        let urlStr = "http://" + baseuri + faceDetectionAPI //   URLConvertible
        Swift.print("urlStr \(urlStr)")
        
        if let image = image
        {
            let headers = [
                "Accept": "application/json",
                "Content-Type": "image/jpeg",
            ]
            
            
            if faceDetectionStartTimes == nil   //
            {
                faceDetectionStartTimes = [String:DispatchTime]()
            }
            faceDetectionStartTimes![service] =  DispatchTime.now() //
            
            let _ = pendingCount.increment()
            
            let url = URL(string: urlStr)
            var urlRequest = URLRequest(url: url!)
            
            urlRequest.httpBody = image.jpegData(compressionQuality: 1.0)
            urlRequest.httpMethod = "POST"
            urlRequest.allHTTPHeaderFields = headers
            urlRequest.allowsCellularAccess = true
            
            Logger.shared.log(.network, .debug, "URL Request is \(urlRequest)")
            
            //send request via URLSession API
            let task = URLSession.shared.dataTask(with: urlRequest as URLRequest, completionHandler: { data, response, error in
                let _ = pendingCount.decrement()
                if (error != nil) {
                    print(error!)
                    promise.reject(error!)
                    Swift.print("error doAFaceDetection")
                } else {
                    let end = DispatchTime.now() // <<<<<<<<<<   end time
                    
                    // Swift.print("")---
                    print("•", terminator:"")
                    
                    if let data = data {
                        do {
                            // Convert the data to JSON
                            let d = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String : AnyObject]
                            let success = d!["success"] as! String
                            if success == "true"
                            {
                                print("Y.\(service) ", terminator:"")
                                // Swift.print("data: \(data)")
                                
                                let start =  self.faceDetectionStartTimes![service] //
                                let nanoTime = end.uptimeNanoseconds - start!.uptimeNanoseconds  //self.faceDetectionStartTime!.uptimeNanoseconds // <<<<< Difference in nano seconds (UInt64)
                                
                                let timeInterval = Double(nanoTime) / 1_000_000_000 // Technically could overflow for long running tests
                                
                                // Swift.print("FaceDetection time: \(timeInterval)")
                                SKToast.show(withMessage: "FaceDetection  time: \(timeInterval) result: \(String(describing: data))")
                                
                                let aa = d!["rects"]
                                
                                let msg =    "FaceDetection" + service
                                
                                NotificationCenter.default.post(name: NSNotification.Name(rawValue: msg), object: aa) //   draw blue rect around face  [[Int]]
                                
                                promise.fulfill(d!)
                                
                                let latency = String(format: "%4.3f", timeInterval * 1000)
                                NotificationCenter.default.post(name: NSNotification.Name(rawValue: broardcastMsg!), object: latency)
                            }
                        } catch {
                            Swift.print("JSON Serialization error")
                            return
                        }
                    }
                }
                if faceDetectCount.decrement() == 0 {
                    faceDetectCount = OSAtomicInt32(3)
                }
            })
            task.resume()
        }
        return promise
    }
    
    // Mark: -
    // Mark: FaceRecognition
    func doNextFaceRecognition()
    {
        // Swift.print("\(#function)")
        
        if faceRecognitionImages2.count == 0    // we put 2 copys of same image and route to cloud/edge
        {
            faceDetectCount = OSAtomicInt32(3)
            
            print("+", terminator:"")
            
            return
        }
        let tuple = faceRecognitionImages2.removeFirst()
        let imageOfFace = tuple.0 as UIImage
        let service = tuple.1 as String
        faceRecognitionCurrentImage = imageOfFace
        
        var faceRecognitionPromise: Promise<[String: AnyObject]>? // async result (captured by async?)
        
        faceRecognitionPromise = FaceRecognition(imageOfFace, service )
        
        faceRecognitionPromise!.then { reply in
            print("FaceRecognition received value: \(reply)")
            
            SKToast.show(withMessage: "FaceRec \(String(describing: reply["subject"])) confidence: \(String(describing: reply["confidence"])) ")
            Swift.print("FaceRecognition \(reply)")
            
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "faceRecognized" + service), object: reply )
            
            DispatchQueue.main.async {
                self.doNextFaceRecognition()     //   next
                
            }
            //Log.logger.name = "FaceDetection"
            //logw("\FaceDetection result: \(registerClientReply)")
            }
            .catch { print("FaceRecognition failed with error: \($0)")
                DispatchQueue.main.async {
                    self.doNextFaceRecognition()     //   next
                    
                }
            }
            .always { // print("completed with result: \($0)")
        }
    }
    
    
    func FaceRecognition(_ image: UIImage?, _ service: String)
        -> Promise<[String: AnyObject]>
    {
        // Swift.print("\(#function)")
        
        let promise = Promise<[String: AnyObject]>.pending()
        
        // Logger.shared.log(.network, .info, image! )      //
        
        // detector/detect
        // Used to send a face image to the server and get back a set of coordinates for any detected faces.
        // POST http://<hostname>:8008/detector/detect/
        
        let faceRecognitonAPI: String = "/recognizer/predict/"
        
        //    Swift.print("FaceRecogniton")
        //    Swift.print("FaceRecogniton MEX .")
        //    Swift.print("====================\n")
        
        
        let postMsg =  "faceRecognitionLatency" + service
        let baseuri = (service ==  "Cloud" ? DEF_FACE_HOST_CLOUD : DEF_FACE_HOST_EDGE)   + ":" + faceServerPort  //
        
        let urlStr = "http://" + baseuri + faceRecognitonAPI //  URLConvertible
        
        Swift.print("urlStr \(urlStr)")
        
        if let image = image
        {
            let headers = [
                "Accept": "application/json",
                "Content-Type": "image/jpeg",
            ]
            
            
            if faceRecognitionStartTimes == nil   // LIT hack
            {
                faceRecognitionStartTimes = [String:DispatchTime]()
            }
            faceRecognitionStartTimes![service] =  DispatchTime.now() //
            
            let url = URL(string: urlStr)
            var urlRequest = URLRequest(url: url!)
            
            urlRequest.httpBody = image.jpegData(compressionQuality: 1.0)
            urlRequest.httpMethod = "POST"
            urlRequest.allHTTPHeaderFields = headers
            urlRequest.allowsCellularAccess = true
            
            Logger.shared.log(.network, .debug, "URL Request is \(urlRequest)")
            
            //send request via URLSession API
            let task = URLSession.shared.dataTask(with: urlRequest as URLRequest, completionHandler: { data, response, error in
                if (error != nil) {
                    print(error!)
                    SKToast.show(withMessage: "FaceRecognition Failed: \(String(describing: error))")
                    promise.reject(error!)
                } else {
                    let end = DispatchTime.now()   // <<<<<<<<<<   end time
                    
                    // Swift.print("")
                    var d: [String: AnyObject]!
                    
                    if let data = data {
                        do {
                            // Convert the data to JSON
                            d = try JSONSerialization.jsonObject(with: data, options: []) as? [String : AnyObject]
                        } catch {
                            Swift.print("JSON Serialization error")
                        }
                    }
                    let success = d["success"] as! String
                    if success == "true"
                    {
                        // Swift.print("data: \(data)")
                        
                        let start =  self.faceRecognitionStartTimes![service] //
                        let nanoTime = end.uptimeNanoseconds - start!.uptimeNanoseconds  //
                        let timeInterval = Double(nanoTime) / 1_000_000_000 // Technically could overflow for long running tests
                        
                        promise.fulfill(d as [String : AnyObject])  //
                        
                        Swift.print("••• FaceRecognition time: \(timeInterval)")
                        
                        SKToast.show(withMessage: "FaceRecognition  time: \(timeInterval) result: \(data)")
                        
                        //    let msg = "FaceRecognized" + service
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "FaceRecognized"), object: d)   //  doNextFaceRecognition "FaceRecognized"
                        
                        
                        let latency = String( format: "%4.3f", timeInterval * 1000 ) //  ms
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: postMsg), object: latency)
                    }
                }
            })
            task.resume()
        }
        return promise
    }
}



func convertPointsToRect(_ a:[Int])  ->CGRect    //   Mex data
{
    let r = CGRect(CGFloat(a[0]), CGFloat(a[1]), CGFloat(a[2] - a[0]), CGFloat(a[3] - a[1])) // face rect
    
    return r
}

// MARK:-

func getNetworkLatencyEdge()
{
    getNetworkLatency( DEF_FACE_HOST_EDGE, post: "latencyEdge")
}

func getNetworkLatencyCloud()
{
    getNetworkLatency( DEF_FACE_HOST_CLOUD, post: "latencyCloud")
}



func getNetworkLatency(_ hostName:String, post name: String)
{
    // Swift.print("\(#function) \(hostName)")
    
    // Ping once
    let  pingOnce = SwiftyPing(host: hostName, configuration: PingConfiguration(interval: 0.5, with: 5), queue: DispatchQueue.global())
    pingOnce?.observer = { (_, response) in
        let duration = response.duration
       // print(duration)
        pingOnce?.stop()
        
        let latency = response.duration * 1000
 
        // print("\(hostName) latency (ms): \(latency)")

        
        let latencyMsg = String( format: "%4.2f", latency )
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: name), object: latencyMsg)
    }
    pingOnce?.start()
}

