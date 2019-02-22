//
//  SideMenuViewController.swift
//  Example
//
//  Created by meta30 on 11/4/18.
//  Copyright © 2018 Xmartlabs. All rights reserved.
//

//  Copyright © 2018 MobiledgeX. All rights reserved.
//

import Foundation

import UIKit
import Eureka

class SideMenuViewController : FormViewController
{
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        title = "Side Menu"
        
        form +++  // Section("")
            
            Section()
//                {
//                $0.header = HeaderFooterView<LogoView>(.class)
//            }
            
            <<< ButtonRow("Sign in with Google")
            {
                $0.title = $0.tag
                $0.presentationMode = .segueName(segueName:
                    "Sign in with Google", onDismiss: nil)
              //  $0.value = "ZSE"
                $0.cellStyle = .subtitle
                }
                .cellSetup { cell, row in
                    cell.imageView?.image = UIImage(named: "g-logo")
                    
              }
            
            <<< ButtonRow("Face Resognition")
            {
                $0.title = $0.tag
                Swift.print("Face Resognition")

               $0.presentationMode = .segueName(segueName:
                    "Face Resognition", onDismiss: nil)
                }
                .cellSetup { cell, row in
                    cell.imageView?.image = UIImage(named: "ios11-control-center-camera-icon")
            }
            
            <<< ButtonRow("Face Detection")
            {
                $0.title = $0.tag
                Swift.print("Face Detection")
              $0.presentationMode = .segueName(segueName:
                  "Face Detection", onDismiss: nil)
                }
                .cellSetup { cell, row in
                    cell.imageView?.image = UIImage(named: "ios11-control-center-camera-icon")
            }
            
            <<< ButtonRow("Settings")
            {
                $0.title = $0.tag
                $0.presentationMode = .segueName(segueName: "Settings", onDismiss: nil)
                }
                .cellSetup { cell, row in
                    cell.imageView?.image = UIImage(named: "Cog_font_awesome.png")
        }
        
            <<< ButtonRow("About")
            {
                $0.title = $0.tag
                $0.presentationMode = .segueName(segueName: "About", onDismiss: nil)
                }
                .cellSetup { cell, row in
                    cell.imageView?.image = UIImage(named: "About")
        }
           form +++  Section("Benchmark")
            <<< ButtonRow("Edge")
            {
                $0.title = $0.tag
               $0.presentationMode = .segueName(segueName: "Edge", onDismiss: nil)
                }
                .cellSetup { cell, row in
                    let im = UIImage(named: "ic_marker_cloudlet-web")
                    
                    let tintColorGray = UIColor(red:0.416, green:0.14, blue:0.416, alpha:0.416)
                    
                    let ti  = im!.imageWithColor( tintColorGray)
                    
                    cell.imageView?.image = ti  // UIImage(named: ti)
        }
            <<< ButtonRow("Local")
            {
                $0.title = $0.tag
                   $0.presentationMode = .segueName(segueName: "Local", onDismiss: nil)
                }
                .cellSetup { cell, row in
                    
                    let im = UIImage(named: "ic_marker_mobile-web")
                    
                    let tintColorGray = UIColor(red:0.416, green:0.14, blue:0.416, alpha:0.416)

                    let ti  = im!.imageWithColor( tintColorGray)
                    
                    cell.imageView?.image = ti //UIImage(named: ti)
        }
        title = "Settings"
        
    }
    
    class  LogoView: UIView {
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            let imageView = UIImageView(image: UIImage(named: "ic_launcher-web"))
            imageView.frame = CGRect(x: 0, y: 0, width: 320, height: 130)
            imageView.autoresizingMask = .flexibleWidth
            self.frame = CGRect(x: 0, y: 0, width: 320, height: 130)
            imageView.contentMode = .scaleAspectFit
            addSubview(imageView)
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        
    }
}



                    extension UIImage
                {
                    func imageWithColor(_ color1: UIColor) -> UIImage {
                    UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
                    color1.setFill()
                    
                    let context = UIGraphicsGetCurrentContext()
                    context?.translateBy(x: 0, y: self.size.height)
                    context?.scaleBy(x: 1.0, y: -1.0)
                    context?.setBlendMode(CGBlendMode.normal)
                    
                    let rect = CGRect(origin: .zero, size: CGSize(width: self.size.width, height: self.size.height))
                    context?.clip(to: rect, mask: self.cgImage!)
                    context?.fill(rect)
                    
                    let newImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    
                    return newImage!
                    }
}

