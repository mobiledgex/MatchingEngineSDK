// Copyright 2019 MobiledgeX, Inc. All rights and licenses reserved.
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
//  Cloudlet.swift
//  MatchingEngineSDK Example
//


import Foundation

import GoogleMaps
import Promises
import MobiledgeXSDK

public class Cloudlet: CustomStringConvertible // implements Serializable? todo?
{
    //  private var cl: Cloudlet?
    
    private static let TAG: String = "Cloudlet"
    public static let BYTES_TO_MBYTES: Int = 1024 * 1024
    
    public var description: String {
        return "<\(type(of: self)): CloudletName = \(mCloudletName)\n AppName = \(mAppName)\n CarrierName = \(mCarrierName)\n\n Latitude= \(mLatitude)\n mLongitude= \(mLongitude)\n\n Distance= \(mDistance)\n\n latencyMin= \(latencyMin)\n latencyAvg= \(latencyAvg)\n latencyMax= \(latencyMax)\n >"
    }
    
    var mCloudletName: String = "" // note legacy m prefix nameing convention
    private var mAppName: String = ""
    private var mCarrierName: String = ""
    
    private var mLatitude: Double = 0
    private var mLongitude: Double = 0
    
    private var mDistance: Double = 0
    private var bestMatch: Bool = false
    
    private var mMarker: GMSMarker? // map marker, POI
    
    var latencyMin: Double = 9999.0
    var latencyAvg: Double = 0
    var latencyMax: Double = 0
    var latencyStddev: Double = 0
    //var latencyTotal: Double = 0
    
    var pings: [String] = [String]()
    var latencies = [Double]()
    var promise:Promise<[String: AnyObject]>? // async result (captured by async?)
    
    private var mbps: Int64 = 0 // BigDecimal.valueOf(0);
    // var latencyTestProgress: Double = 0
    private var speedTestProgress: Double = 0 // 0-1  //  updating
    var startTime: Double = 0 // Int64
    var startTime1: DispatchTime?
    var timeDifference: Double = 0
    var mNumPackets: Int = 4 // number of pings
    private var mNumBytes: Int = 1_048_576
    private var runningOnEmulator: Bool = false
    var pingFailed: Bool = false
    
    private var mBaseUri: String = ""
    private var downloadUri: String = "" // rebuilt at runtime
    private var socketdUri: String = "" // rebuilt at runtime
    
    var hostName: String = ""
    var openPort: Int = 7777
    let socketTimeout: Int = 3000
    var latencyTestTaskRunning: Bool = false
    var speedTestTaskRunning: Bool = false
    private var uri: String = ""
    private var theFQDN_prefix: String = ""
    
    private var sessionDelegate = SessionDelegate()
    
    init()
    {}
    
    init(_ cloudletName: String,
         _ appName: String,
         _ carrierName: String,
         _ gpsLocation: CLLocationCoordinate2D,
         _ distance: Double,
         _ uri: String,
         _ urlPrefix: String,
         _ marker: GMSMarker,
         _ numBytes: Int,
         _ numPackets: Int) // LatLng
    {
        Swift.print("Cloudlet contructor. cloudletName= \(cloudletName)")
        
        update(cloudletName, appName, carrierName, gpsLocation, distance, uri, urlPrefix, marker, numBytes, numPackets)
        
        let autoStart = UserDefaults.standard.bool(forKey: "Latency Test Auto-Start")
        
        if autoStart
        {
            let numPings = Int(UserDefaults.standard.string(forKey: "Latency Test Packets") ?? "4") //
            runLatencyTest(numPings: numPings!) //runLatencyTest
        }
        else
        {

        }
        
        if CloudletListHolder.getSingleton().getLatencyTestAutoStart()
        {
            // All AsyncTask instances are run on the same thread, so this queues up the tasks.
            startLatencyTest()
        }
        else
        {
            Swift.print("LatencyTestAutoStart is disabled")
        }
        
        sessionDelegate.parent = self
    }
    
    public func update(_ cloudletName: String,
                       _ appName: String,
                       _ carrierName: String,
                       _ gpsLocation: CLLocationCoordinate2D,
                       _ distance: Double,
                       _ uri: String,
                       _ urlPrefix: String,
                       _ marker: GMSMarker,
                       _ numBytes: Int,
                       _ numPackets: Int) // # packets to ping
        
    {
        Swift.print("Cloudlet update. cloudletName= \(cloudletName)")
        
        mCloudletName = cloudletName
        mAppName = appName
        mCarrierName = carrierName
        mLatitude = gpsLocation.latitude
        mLongitude = gpsLocation.longitude
        mDistance = distance
        mMarker = marker
        mNumBytes = numBytes
        mNumPackets = numPackets
        
        mBaseUri = uri
        theFQDN_prefix = urlPrefix
        setDownloadUri(uri)
        
        //    let numPings = Int(UserDefaults.standard.string(forKey: "Latency Test Packets") ?? "5")
        
    }
    
    func runLatencyTest(numPings: Int)
    {
        latencyTestTaskRunning = false
        
        if latencyTestTaskRunning
        {
            Swift.print("LatencyTest already running")
            SKToast.show(withMessage: "LatencyTest already running")
            return
        }
        latencyTestTaskRunning = true
        
        let azure = uri.range(of: "azure") != nil
        if uri != "" //&&
        {
            Swift.print("uri: \(uri)")
            // Ping several times
            latencies.removeAll()
            pings.removeAll()
            
            for _ in 0 ..< numPings
            {
                if azure
                {
                    pings.append(socketdUri)
                }
                else
                {
                    pings.append(uri) //  N pings
                }
            }
            
            pingNext()
        }
        
        // post upateLatencies
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateLatencies"), object: nil)
        
        dump()
    }
    
    deinit
    {
        NotificationCenter.default.removeObserver(self)
    }
    
    func pingNext()
    {
        guard pings.count > 0 else
        {
            latencyTestTaskRunning = false //
            
            return
        }
        
        Swift.print("0latencies \(self.latencies)")
        
        let host = pings.removeFirst()
        
        //  let latencyTestMethod = UserDefaults.standard.string(forKey: "LatencyTestMethod")
        var useSocket = false
        Swift.print("uri \(uri)")
        if ( uri.contains("azure"))
        {
            useSocket = true
        }
        
        if useSocket    // &&  latencyTestMethod == "Socket"
        {
            promise = GetSocketLatency(host, 7777).then {
                let d = $0 as [String: Any]
                
                print("GetSocketLatency: \(d["latency"])")
                let duration = Double(d["latency"] as! String  )
                
                // print("\(ping) latency (ms): \(latency)")
                self.latencies.append(duration! * 1000)
                
                Swift.print("latencies \(self.latencies)")
                
                self.latencyMin = self.latencies.min()!
                self.latencyMax = self.latencies.max()!
                
                let sumArray = self.latencies.reduce(0, +)
                
                self.latencyAvg = sumArray / Double(self.latencies.count)
                
                self.latencyStddev = standardDeviation(arr: self.latencies)
                
                Swift.print("•latencyMin \(self.latencyMin)")
                Swift.print("latencyMax \(self.latencyMax)")
                Swift.print("latencyAvg \(self.latencyAvg)")
                Swift.print("latencyStddev \(self.latencyStddev)")
                
                let latencyMsg = String(format: "%4.3f", self.latencyAvg)
                
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateLatencies"), object: latencyMsg)
                
                self.pingNext()
            }
            .catch { error in
                    print("Socket failed with error: \(error)")
            }
            .always { // print("completed with result: \($0)" )
            }
        }
        else
        {
            // Ping once
            let pingOnce = SwiftyPing(host: host, configuration: PingConfiguration(interval: 0.5, with: 5), queue: DispatchQueue.global())
            
            pingOnce?.observer = { _, response in
                let duration = response.duration
                print("cloudlet latency: \(duration)")
                pingOnce?.stop()
                
                // print("\(ping) latency (ms): \(latency)")
                self.latencies.append(response.duration * 1000)
                
                Swift.print("latencies \(self.latencies)")
                
                self.latencyMin = self.latencies.min()!
                self.latencyMax = self.latencies.max()!
                
                let sumArray = self.latencies.reduce(0, +)
                
                self.latencyAvg = sumArray / Double(self.latencies.count)
                
                Swift.print("••latencyMin \(self.latencyMin)")
                Swift.print("latencyMax \(self.latencyMax)")
                Swift.print("latencyAvg \(self.latencyAvg)")
                Swift.print("latencyStddev \(self.latencyStddev)")
                
                self.latencyStddev = standardDeviation(arr: self.latencies)
                
                let latencyMsg = String(format: "%4.3f", self.latencyAvg)
                
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateLatencies"), object: latencyMsg)
                self.pingNext()
            }
            pingOnce?.start()
        }
        
    }
    
    /**
     * From the given string, create the hostname that will be pinged,
     * and the URI that will be downloaded from.
     * @param uri
     */
    public func setDownloadUri(_ uri: String)
    {
        if mCarrierName.caseInsensitiveCompare("GDDT") == .orderedSame
        {
            openPort = 443
            hostName = uri
            //     hostName = theFQDN_prefix + uri
            
            //       downloadUri = "https://\(hostName)/mobiledgexsdkdemohttp/getdata?numbytes=\(mNumBytes)"
            openPort = 7777
            
            let downLoadStringSize = UserDefaults.standard.string(forKey: "Download Size") ?? "1 MB"
            let n = downLoadStringSize.components(separatedBy: " ")
            
            mNumBytes = Int(n[0])! * 1_048_576
            
            downloadUri = "http://\(hostName):\(openPort)/getdata?numbytes=\(mNumBytes)"
            Swift.print("downloadUri1: \(downloadUri)") // DEBUG
            
            socketdUri = hostName
        }
        else
        {
            openPort = 7777
            hostName = theFQDN_prefix + uri
            downloadUri = "http://\(hostName):\(openPort)/getdata?numbytes=\(mNumBytes)"
            Swift.print("downloadUri: \(downloadUri)") // DEBUG
            
            socketdUri = hostName
        }
        self.uri = uri
    }
    
    public func getUri() -> String
    {
        return uri
    }
    
    public func toString() -> String
    {
        return "mCarrierName=\(mCarrierName) mCloudletName=\(mCloudletName) mLatitude=\(mLatitude) mLongitude=\(mLongitude) mDistance=\(mDistance) uri=\(uri)"
    }
    
    public func startLatencyTest()
    {
        Swift.print("startLatencyTest()")
        if latencyTestTaskRunning
        {
            Swift.print("LatencyTest already running")
            return
        }
        
        latencyTestTaskRunning = true //
        
        latencyMin = 9999
        latencyAvg = 0
        latencyMax = 0
        latencyStddev = 0
        //latencyTotal = 0
        
        // ping can't run on an emulator, so detect that case.
        //  Swift.print("PRODUCT= \(Build.PRODUCT)")
        
        if isSimulator
        {
            runningOnEmulator = true
            // Log.i(TAG, "YES, I am an emulator.");
            Swift.print("YES, I am an emulator/simulator.")
        }
        else
        {
            runningOnEmulator = false
            Swift.print("NO, I am NOT an emulator/simulator.")
        }
        
        var latencyTestMethod: CloudletListHolder.LatencyTestMethod
            = CloudletListHolder.getSingleton().getLatencyTestMethod()
        
        if mCarrierName.caseInsensitiveCompare("azure") == .orderedSame
        {
            Swift.print("Socket test forced for Azure")
            
            latencyTestMethod = CloudletListHolder.LatencyTestMethod.socket
        }
        if runningOnEmulator
        {
            Swift.print("Socket test forced for emulator")
            latencyTestMethod = CloudletListHolder.LatencyTestMethod.socket
        }
        
        if latencyTestMethod == CloudletListHolder.LatencyTestMethod.socket
        {
            Swift.print("LatencyTestTaskSocket todo?")
            //  LatencyTestTaskSocket().execute();
        }
        else if latencyTestMethod == CloudletListHolder.LatencyTestMethod.ping
        {
            Swift.print("LatencyTestTaskPing todo?")
            // LatencyTestTaskPing().execute();
        }
        else
        {
            Swift.print("Unknown latencyTestMethod: \(latencyTestMethod) ")
        }
    }
    
    public func getCloudletName() -> String
    {
        return mCloudletName
    }
    
    public func setCloudletName(_ mCloudletName: String)
    {
        self.mCloudletName = mCloudletName
    }
    
    public func getCarrierName() -> String
    {
        return mCarrierName
    }
    
    public func setCarrierName(_ mCarrierName: String)
    {
        self.mCarrierName = mCarrierName
    }
    
    public func getLatitude() -> Double
    {
        return mLatitude
    }
    
    public func setLatitude(Latitude: Double)
    {
        mLatitude = Latitude
    }
    
    public func getLongitude() -> Double
    {
        return mLongitude
    }
    
    public func setLongitude(mLongitude: Double)
    {
        self.mLongitude = mLongitude
    }
    
    public func getDistance() -> Double
    {
        return mDistance
    }
    
    public func setDistance(_ mDistance: Double)
    {
        self.mDistance = mDistance
    }
    
    public func getMarker() -> GMSMarker
    { return mMarker! }
    
    public func setMarker(_ mMarker: GMSMarker) { self.mMarker = mMarker }
    
    public func isBestMatch() -> Bool { return bestMatch }
    
    public func setBestMatch(_ bestMatch: Bool) { self.bestMatch = bestMatch }
    
    public func getLatencyMin() -> Double
    {
        return latencyMin
    }
    
    public func getLatencyAvg() -> Double
    {
        return latencyAvg
    }
    
    public func getLatencyMax() -> Double
    {
        return latencyMax
    }
    
    public func getLatencyStddev() -> Double
    {
        return latencyStddev
    }
    
    public func getMbps() -> Int64
    {
        return mbps
    }
    
    //    public func getLatencyTestProgress() -> Double
    //    {
    //        return latencyTestProgress
    //    }
    
    public func getSpeedTestProgress() -> Double
    {
        return speedTestProgress
    }
    
    public func isPingFailed() -> Bool
    {
        return pingFailed
    }
    
    public func setPingFailed(_ pingFailed: Bool)
    {
        self.pingFailed = pingFailed
    }
    
    public func isLatencyTestTaskRunning() -> Bool
    {
        return latencyTestTaskRunning
    }
    
    public func setLatencyTestTaskRunning(_ latencyTestTaskRunning: Bool)
    {
        self.latencyTestTaskRunning = latencyTestTaskRunning
    }
    
    public func getAppName() -> String
    {
        return mAppName
    }
    
    public func setAppName(_ mAppName: String)
    {
        self.mAppName = mAppName
    }
    
    public func getNumPackets() -> Int
    { return mNumPackets }
    
    public func setNumPackets(_ mNumPings: Int) { mNumPackets = mNumPings }
    
    public func getNumBytes() -> Int
    { return mNumBytes }
    
    public func setNumBytes(_ mNumBytes: Int) { self.mNumBytes = mNumBytes }
    
    var isSimulator: Bool
    {
        #if arch(i386) || arch(x86_64)
        return true
        #else
        return false
        #endif
    }
    
    private class SessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
        weak var parent: Cloudlet! = nil
        
        //Updates progress of urlsession
        public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64,totalBytesExpectedToWrite: Int64) {
            
            let fractionCompleted = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "speedTestProgress"), object: fractionCompleted)
            parent.speedTestProgress = fractionCompleted
        }
    }
    
    func doSpeedTest()
    {
        if speedTestTaskRunning
        {
            Swift.print("SpeedTest already running")
            SKToast.show(withMessage: "SpeedTest already running") // UI
            
            return
        }
        speedTestTaskRunning = true //
        setDownloadUri(mBaseUri) // so we have current B bytes to download appended
        Swift.print("doSpeedTest\n  \(downloadUri)") // DEBUG
        startTime1 = DispatchTime.now() // <<<<<<<<<< Start time
 
        let url = URL(string: downloadUri)
        let urlRequest = URLRequest(url: url!)
        // Create new URLSession in order to use delegates
        let session = URLSession.init(configuration: URLSessionConfiguration.default, delegate: sessionDelegate, delegateQueue: OperationQueue.main)
        
        let dataTask = session.dataTask(with: urlRequest as URLRequest) { (data, response, error) in
            guard let _ = response as? HTTPURLResponse else
            {
                print("Response not HTTPURLResponse")
                return
            }
            self.speedTestTaskRunning = false
            // check for errors
            guard error == nil else
            {
                // got an error in getting the data, need to handle it
                print("error doSpeedTest")
                print(error!)
                DispatchQueue.main.async
                {
                    CircularSpinner.hide() //
                }
                return
            }
            
            let end = DispatchTime.now() // <<<<<<<<<<   end time
            let nanoTime = end.uptimeNanoseconds - self.startTime1!.uptimeNanoseconds // <<<<< Difference in nano seconds (UInt64)
            let timeInterval = Double(nanoTime) / 1_000_000_000 // Technically could overflow for long running tests
            print("Time: \(timeInterval) seconds")
            let tranferRateD = Double(self.mNumBytes) / timeInterval
            let tranferRate = Int(tranferRateD)
                    
            Swift.print("[COMPLETED] rate in bit/s   : \(tranferRate * 8)") // Log
                    
            SKToast.show(withMessage: "[COMPLETED] rate in MBs   : \(Double(tranferRate) / (1024 * 1024.0))") // UI
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "tranferRate"), object: tranferRate) // post
        }
        dataTask.resume()
    }
    
    func dump()
    {
        Swift.print("latencyMin \(latencyMin)")     // JT
        Swift.print("latencyAvg \(latencyAvg)")     // JT
        Swift.print("latencyMax \(latencyMax)")     // JT
        Swift.print("latencyStddev \(latencyStddev)")     // JT
    }
    

}


extension UIDevice
{
    var isSimulator: Bool
    {
        #if arch(i386) || arch(x86_64)
            return true
        #else
            return false
        #endif
    }
}


func GetSocketLatency(_ host: String, _ port: Int32, _ postMsg: String? = nil)  -> Promise<[String: AnyObject]>
    
{
    let promise = Promise<[String: AnyObject]>.pending() // completion callback
    
    DispatchQueue.global(qos: .background).async
    {
        let time = measure1
        {
            // used to store addrinfo fields like sockaddr struct, socket type, protocol, and address length
            var res: UnsafeMutablePointer<addrinfo>!
            // initialize addrnfo fields
            var addrInfo = addrinfo.init()
            addrInfo.ai_socktype = SOCK_STREAM // TCP stream socket
            // getaddrinfo function makes ip + port conversion to sockaddr easy
            let error = getaddrinfo(host, String(port), &addrInfo, &res)
            if error != 0 {
                promise.reject("Can't get addrinfo. Error is \(error)" as! Error)
            }
            // socket returns a socket descriptor
            let s = socket(res.pointee.ai_family, res.pointee.ai_socktype, 0)
            if s == -1 {
                promise.reject("Can't create socket. Error is \(error)" as! Error)
            }
            let c = connect(s, res.pointee.ai_addr, res.pointee.ai_addrlen)
            if c == -1 {
                promise.reject("Can't connect to socket. Error is \(error)" as! Error)
            }
            close(s)
        }

        // print("host: \(host)\n Latency \(time / 1000.0) ms")
        if time > 0
        {
            let latencyMsg = String(format: "%4.2f", time  )
            
            if postMsg != nil && postMsg != ""
            {
                let latencyMsg2 = String(format: "%4.2f", time  ) // ms
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: postMsg!), object: latencyMsg2)
            }
            promise.fulfill(["latency": latencyMsg as AnyObject])
        }
        
        
    }
    
    return promise
}

// MARK: - Utility

func measure<T>(task: () -> T) -> Double
{
    let startTime = CFAbsoluteTimeGetCurrent()
    _ = task()
    let endTime = CFAbsoluteTimeGetCurrent()

    let result = endTime - startTime

    return result
}

func measure1<T>(task: () -> T) -> Double
{
    let startTime = DispatchTime.now()
    _ = task()
    let endTime = DispatchTime.now()

    let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds

    let timeInterval = Double(nanoTime) / 1_000_000_000 // Technically could overflow for long running tests

    return timeInterval
}


func standardDeviation(arr: [Double]) -> Double //
{
    let length = Double(arr.count)
    let avg = arr.reduce(0, { $0 + $1 }) / length
    let sumOfSquaredAvgDiff = arr.map { pow($0 - avg, 2.0) }.reduce(0, { $0 + $1 })
    
    return sqrt(sumOfSquaredAvgDiff / length)
}

