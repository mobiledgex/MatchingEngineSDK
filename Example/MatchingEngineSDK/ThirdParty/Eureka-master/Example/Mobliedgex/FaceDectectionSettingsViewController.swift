//
//  FaceDectectionSettingsViewController.swift
//  Example
//
//  Created by meta30 on 11/3/18.
//  Copyright © 2018 MobiledgeX. All rights reserved.
//


import Foundation

import UIKit
import Eureka

class FaceDectectionSettingsViewController : FormViewController
{
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        title = "Face Dectection Setting"
        
        
        form +++   Section()
            
            //            Section() {
            //                $0.header = HeaderFooterView<EurekaLogoView>(.class)
            //            }
            
            <<< SwitchRow() {
                $0.title = "Multi-face"
                $0.value = UserDefaults.standard.bool(forKey: "Multi-face")    // initially selected

                }.onChange { [weak self] row in
                    
                    Swift.print("Multi-face \(row)")
                    
                    Swift.print("Multi-face \(row) \(row.value!)")
                    
                    UserDefaults.standard.set(row.value, forKey:"Multi-face" )

            }
                .cellSetup { cell, row in
                  row.subTitle = " Track multiple faces"
            }
            <<< SwitchRow() {
                $0.title = "Local processing"
                $0.value = UserDefaults.standard.bool(forKey: "Local processing")    // initially selected
                }.onChange { [weak self] row in
                    
                    Swift.print("Local processing" + " \(row) \(row.value!)")
                    
                    UserDefaults.standard.set(row.value, forKey:"Local processing" )
            }
                .cellSetup { cell, row in
                    row.subTitle = " Include tracking via local processing "
            }
            <<< SwitchRow() {
                $0.title = "Show full process latancy"
                $0.value = UserDefaults.standard.bool(forKey: "Show full process latancy")    // initially selected
                }.onChange { [weak self] row in
                    
                    Swift.print("Show full process latancy"  + " \(row) \(row.value!)")
                    
                    UserDefaults.standard.set(row.value, forKey:"Show full process latancy"  )
            }
                .cellSetup { cell, row in
                    row.subTitle = " Measure all"
            }
            <<< SwitchRow() {
                $0.title = "Show network latancy"
                $0.value = UserDefaults.standard.bool(forKey: "Show network latancy")    // initially selected
                }.onChange { [weak self] row in
                    
                    Swift.print("Show network latancy"  + " \(row) \(row.value!)")
                    
                    UserDefaults.standard.set(row.value, forKey:"Show network latancy"  )
                }
                .cellSetup { cell, row in
                    row.subTitle = " Measures only network latency"
            }
            
            <<< SwitchRow() {
                $0.title = "Show Stddev"
                $0.value = UserDefaults.standard.bool(forKey: "Show Stddev")    // initially selected
                }.onChange { [weak self] row in
                    
                    
                    Swift.print("Show Stddev"  + " \(row) \(row.value!)")
                    
                    UserDefaults.standard.set(row.value, forKey:"Show Stddev"  )
        }
                .cellSetup { cell, row in
                    row.subTitle = " Standard deviation"
            }
            
            <<< SwitchRow() {
                $0.title = "Use Rolling Average"
                $0.value = UserDefaults.standard.bool(forKey: "Use Rolling Average")    // initially selected
                }.onChange { [weak self] row in
                    
                    Swift.print("Use Rolling Average"  + " \(row) \(row.value!)")
                    
                    UserDefaults.standard.set(row.value, forKey:"Use Rolling Average"  )
                    
                }  .cellSetup { cell, row in
                    row.subTitle = " Show measurements and rolling average."
        }
    }
    
}

