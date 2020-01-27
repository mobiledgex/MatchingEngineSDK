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
//  EnhancedNetworkLocationServicesViewController.swift
//  MatchingEngineSDK Example
//


import Foundation

import UIKit

class EnhancedNetworkLocationServicesViewController: FormViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()

        title = "Enhanced Network Location Services"

        form +++ Section()

            //            Section() {
            //                $0.header = HeaderFooterView<EurekaLogoView>(.class)
            //            }

            <<< SwitchRow
        {
            $0.title = "Location Verification"
            $0.value = UserDefaults.standard.bool(forKey: "Location Verification") // initially selected
        }.onChange
        { /*[weak self]*/ row in
            Swift.print("Location Verification \(row) \(row.value!)")

         //   UserDefaults.standard.set(row.value, forKey: "Location Verification")
            UserDefaults.standard.set( row.value, forKey: "VerifyLocation")

        }.cellSetup
        { _, row in
            row.subTitle = " Enhanced Network Location Services."
        }

        #if false
//        <<< SwitchRow
//            {
//                $0.title = "Network Switching Enabled"
//                $0.value = UserDefaults.standard.bool(forKey: "Network Switching Enabled") // initially selected
//            }.onChange
//            { /*[weak self]*/ row in
//                Swift.print("Network Switching Enabled \(row)")
//
//                UserDefaults.standard.set(row.value, forKey: "Network Switching Enabled")
//
//            }.cellSetup
//            { _, row in
//                row.subTitle = " Wifi to Cell network switching"
//        }

        #endif

    }
}
