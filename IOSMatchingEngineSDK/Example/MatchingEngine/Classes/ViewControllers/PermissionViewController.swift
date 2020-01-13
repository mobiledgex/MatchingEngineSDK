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
//  PermissionViewController.swift
//  MatchingEngineSDK Example
//

import Foundation
import SPPermissions

class PermissionViewController: UIViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()

        title = "Permissions"
    }

    @IBAction func why1Action(_: Any)
    {
        Swift.print("why1Action")

        showWhy1()
    }

    @IBAction func why2Action(_: Any)
    {
        Swift.print("why2Action")

        showWhy2()
    }


    func showWhy1()
    {
        let alert = UIAlertController(title: "Alert", message: "App needs your loation to verify it.", preferredStyle: .alert) // .actionSheet)

        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            // execute some code when this option is selected
        }))

        present(alert, animated: true, completion: nil)
    }

    func showWhy2()
    {
        let alert = UIAlertController(title: "Alert", message: "Why app needs permission is to verify location.", preferredStyle: .alert) // .actionSheet)

        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            // execute some code when this option is selected
        }))

        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func okAction(_: Any)
    {
        Swift.print("okAction")
        presentPermissonDialog()
    }
    @objc func presentPermissonDialog()
    {
        let controller = SPPermissions.dialog([.locationWhenInUse, .camera])
        controller.dataSource = self
        controller.delegate = self
        controller.present(on: self)
    }
}

extension PermissionViewController: SPPermissionsDelegate
{ 
    func didHide()
    {
        print("SPPermissionDialogDelegate - didHide")
    }

    func didAllow(permission _: SPPermission)
    {
        //  print("SPPermissionDialogDelegate - didAllow \(permission.name)")
        Swift.print("didAllow")
        
        UserDefaults.standard.set( true, forKey: "firstTimeUsagePermission")

        let _ = navigationController?.popViewController(animated: true)
        

        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "permissionGrantedGetLocaltionUpdates"), object: nil)

    }

    func didDenied(permission _: SPPermission)
    {
        // print("SPPermissionDialogDelegate - didDenied \(permission.name)")
    }
    
    // default titles if not implemented
    /*func deniedData(for permission: SPPermission) -> SPPermissionDeniedAlertData?
    {
        return nil
    }*/
}

extension PermissionViewController: SPPermissionsDataSource
{
    func configure(_ cell: SPPermissionTableViewCell, for permission: SPPermission) -> SPPermissionTableViewCell {
        // default configuration
        return cell
    }
}
