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
//  Site.swift
//

import Foundation

extension MobiledgeXiOSLibraryGrpc.PerformanceMetrics {
    
    /// Object used by NetTest to test latency of server.
    /// Each site object contains the server path or host + port, avg latency, standard deviation, list of latency times, and the TestType.
    /// TestType is either PING or CONNECT, where PING is ICMP Ping (not implemented) and CONNECT is is actually setting up a connection and then disconnecting immediately.
    @available(iOS 13.0, *)
    public class Site {
   
        public var host: String?
        public var port: UInt16?
        public var l7Path: String? // http path
        public var netInterfaceType: String?
        public var localEndpoint: String?
        public var testType: NetTest.TestType

        public var lastPingMs: Double?
        public var avg: Double
        public var stdDev: Double

        public var samples: [Double]
        public var capacity: Int
        
        public var appInst: DistributedMatchEngine_Appinstance?
        public var cloudletLocation: DistributedMatchEngine_Loc?

        var unbiasedAvg: Double // take average to prevent imprecision
        var unbiasedSquareAvg: Double

        let DEFAULT_CAPACITY = 5

        /// initialize size with host and port
        public init(host: String, port: UInt16, testType: NetTest.TestType?, numSamples: Int?, netInterfaceType: String? = nil, localEndpoint: String? = nil) {
            self.host = host
            self.port = port
            samples = [Double]()
            avg = 0.0
            stdDev = 0.0
            unbiasedAvg = 0.0
            unbiasedSquareAvg = 0.0

            self.testType = testType != nil ? testType! : NetTest.TestType.CONNECT // default
            self.capacity = numSamples != nil ? numSamples! : DEFAULT_CAPACITY
            self.netInterfaceType = netInterfaceType
            self.localEndpoint = localEndpoint
        }

        /// initialize http site
        public init(l7Path: String, testType: NetTest.TestType?, numSamples: Int?, netInterfaceType: String? = nil, localEndpoint: String? = nil) {
            self.l7Path = l7Path
            samples = [Double]()
            avg = 0.0
            stdDev = 0.0
            unbiasedAvg = 0.0
            unbiasedSquareAvg = 0.0

            self.testType = testType != nil ? testType! : NetTest.TestType.CONNECT // default
            self.capacity = numSamples != nil ? numSamples! : DEFAULT_CAPACITY
            self.netInterfaceType = netInterfaceType
            self.localEndpoint = localEndpoint
        }

        public func addSample(sample: Double) {
            self.lastPingMs = sample
            samples.append(sample)
            lastPingMs = sample

            // rolling average
            var removed: Double?
            if samples.count > capacity {
                removed = samples.remove(at: 0)
            }
            updateStats(removedVal: removed)
        }
        
        public func getDmeSamples() -> [DistributedMatchEngine_Sample] {
            var dmeSamples: [DistributedMatchEngine_Sample] = []
            for sample in self.samples {
                var dmeSample = DistributedMatchEngine_Sample.init()
                dmeSample.value = sample
                dmeSamples.append(dmeSample)
            }
            return dmeSamples
        }

        private func updateStats(removedVal: Double?) {
            updateAvg(removedVal: removedVal)
            updateStdDev(removedVal: removedVal)
        }

        // constant time update to average
        private func updateAvg(removedVal: Double?) {
            var sum: Double
            // check if adding to samples or replacing element in samples
            if let remove = removedVal {
            sum = avg * Double(samples.count)
            sum -= remove
            } else {
            sum = avg * Double(samples.count - 1)
            }
            sum += lastPingMs!
            self.avg = sum / Double(samples.count)
        }

        // constant time update to stdDev
        // Expanding the formula for standard deviation yields 3 terms:
        // 1) sum of squared samples
        // 2) sum of samples multiplied by 2*mean
        // 3) squared mean multiplied by number of samples
        // (each of these terms are divided by n-1 for an unbiased sample standard deviation)
        private func updateStdDev(removedVal: Double?) {

            // prevent dividing by 0, no stddev from sample size <= 1
            if (samples.count > 1) {

                var sum: Double
                var sumSquare: Double

                // samples is full, replacing oldest sample (rolling window)
                if let remove = removedVal {
                   
                   sum = unbiasedAvg * Double(samples.count - 1)
                   sum -= remove
                   sum += lastPingMs!
                   self.unbiasedAvg = sum / Double(samples.count - 1)
                   
                   sumSquare = unbiasedSquareAvg * Double(samples.count - 1)
                   sumSquare -= remove * remove
                   sumSquare += lastPingMs! * lastPingMs!
                   self.unbiasedSquareAvg = sumSquare / Double(samples.count - 1)

                // samples is not yet filled
                } else {
                   
                   sum = samples.count == 2 ? unbiasedAvg * Double(self.samples.count - 1) : unbiasedAvg * Double(samples.count - 2)
                   sum += lastPingMs!
                   self.unbiasedAvg = sum / Double(samples.count - 1)
                   
                   sumSquare = samples.count == 2 ? unbiasedSquareAvg * Double(samples.count - 1): unbiasedSquareAvg * Double(samples.count - 2)
                   sumSquare += lastPingMs! * lastPingMs!
                   self.unbiasedSquareAvg = sumSquare / Double(samples.count - 1)
                }

                let term1 = unbiasedSquareAvg
                let term2 = 2.0 * avg * unbiasedAvg
                let term3 = Double(samples.count) * avg * avg / Double(samples.count - 1)
                self.stdDev = sqrt(term1 - term2 + term3)

            } else {

                self.unbiasedAvg += lastPingMs!
                self.unbiasedSquareAvg += lastPingMs! * lastPingMs!
            }
        }
    }
}

@available(iOS 13.0, *)
extension MobiledgeXiOSLibraryGrpc.PerformanceMetrics.Site: Equatable {
    public static func == (lhs: MobiledgeXiOSLibraryGrpc.PerformanceMetrics.Site, rhs: MobiledgeXiOSLibraryGrpc.PerformanceMetrics.Site) -> Bool {
        return
            lhs.l7Path == rhs.l7Path &&
            lhs.host == rhs.host &&
            lhs.port == rhs.port
    }
}
