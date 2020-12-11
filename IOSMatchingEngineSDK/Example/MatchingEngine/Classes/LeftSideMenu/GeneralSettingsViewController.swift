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
//  GeneralSettingsViewController.swift
//  MatchingEngineSDK Example
//


import Foundation

import UIKit

import Eureka

class GeneralSettingsViewController: FormViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()

        title = "General Settings"

        form +++ Section("")    // Eureka

            <<< AlertRow<String>() // ActionSheetRow
        {
            $0.title = "DME Selection"
            $0.selectorTitle = "DME Selection"
            $0.options = ["Demo", "TDG Integraton"]
            $0.value = UserDefaults.standard.string(forKey: "DME Selection") ?? "Demo" // initially selected
        }.onChange
        { /* [weak self] */ row in
            Swift.print("DME Selection" + "\(row) \(row.value!)")

            UserDefaults.standard.set(row.value, forKey: "DME Selection")
//
//            Demo (mexdemo) - mexdemo.dme.mobiledgex.net
//                > DME API Reorg (tdg2) - tdg2.dme.mobiledgex.net
//                    > Automation Testing (automationbonn) - automationbonn.dme.mobiledgex.net
            
        }
    }
}
