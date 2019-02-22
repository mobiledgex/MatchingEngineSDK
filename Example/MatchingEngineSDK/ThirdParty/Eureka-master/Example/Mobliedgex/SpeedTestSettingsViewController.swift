//
//  SpeedTestSettingsViewController.swift
//  Example
//
//  Created by meta30 on 11/3/18.
//  Copyright © 2018 MobiledgeX. All rights reserved.
//


import Foundation

import UIKit
import Eureka

class SpeedTestSettingsViewController : FormViewController
{
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        title = "Speed Test Settings"
        
        form +++   Section("")
            
            <<< ActionSheetRow<String>() {
                $0.title = "Download Size"
                $0.selectorTitle = "Download Size"
                $0.options = ["1 MB","5 MB","10 MB","20 MB"]
                $0.value = UserDefaults.standard.string(forKey: "Download Size") ?? "1 MB"    // initially selected
                }.onChange { [weak self] row in
                    
                    Swift.print("Download Size \(row.value)")
                    UserDefaults.standard.set(row.value, forKey: "Download Size" )
                    
                    row.subTitle = "Number of Megabytes to download for speed test"

            }
            
            <<< ActionSheetRow<String>() {
                $0.title = "Latency Test Packets"
                $0.selectorTitle = "Latency Test Packets"
                $0.options = ["4","10","20"]
                $0.value = UserDefaults.standard.string(forKey: "Latency Test Packets") ?? "4"    // initially selected
                } .onChange { [weak self] row in
                    
                    Swift.print("Latency Test Packets" + " \(row)")
                    UserDefaults.standard.set(row.value, forKey: "Latency Test Packets" )
                    
                    row.subTitle = "Number ot times to repeat latency test"

            }
            
            <<< ActionSheetRow<String>() {
                $0.title = "Latency Test Method"
                $0.selectorTitle = "Latency Test Method"
                $0.options = ["System Ping (ICMP)","Socket"]
               // $0.value = "System Ping (ICMP)"    // initially selected
                 $0.value = UserDefaults.standard.string(forKey: "Latency Test Method") ?? "System Ping (ICMP)"    // initially selected
            }
                .onChange { [weak self] row in
                    
                    Swift.print("Latency Test Method" + " \(row)")
                    UserDefaults.standard.set(row.value, forKey: "Latency Test Method" )
                    
                    row.subTitle = "Select socket conection or ICMP ping"

            }
            <<< SwitchRow() {
                $0.title = "Latency Test Auto-Start"
                $0.value = UserDefaults.standard.bool(forKey: "Latency Test Auto-Start")    // initially selected
                }.onChange { [weak self] row in
                    
                    Swift.print("Latency Test Auto-Start \(row)")
                    UserDefaults.standard.set(row.value, forKey: "Latency Test Auto-Start" )

                    row.subTitle = "When cloudlet discovered"

        }
    }
    
}


