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
//  AppDelegate.swift
//  MatchingEngineSDK Example
//


import UIKit

import GoogleMaps
import GoogleSignIn

import os.log
import MobiledgeXiOSLibraryGrpc

@available(iOS 13.0, *)
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate
{
    var services: Any? //   = GMSServices.sharedServices()
    var matchingEngine: MobiledgeXiOSLibraryGrpc.MatchingEngine!
    var myViewController: ViewController!

    #warning ("Action item: you need to replace the values assigned: API Key and ClientID are specific to each app.")
    let kAPIKey = "***REMOVED***"
    let kClientID = "986302029352-9ctsr3cu2rf2irj616cjilh84bp8chj5.apps.googleusercontent.com" // For this iOS demo FaceDetection Example

    
    
    var window: UIWindow?
    
    /// Where it all starts
    ///
    /// Initialize one (or more) MatchingEngines.
    ///
    /// Do Google GIDSignIn and GMSServices
    /// init loggng options
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    {
        matchingEngine = MobiledgeXiOSLibraryGrpc.MatchingEngine()

        #if true    // GIDSignIn
            GIDSignIn.sharedInstance().clientID = kClientID
            GIDSignIn.sharedInstance().delegate = self
        #endif
        
        GMSServices.provideAPIKey(kAPIKey) // for maps
        services = GMSServices.sharedServices()
        
        return true
    }

    func application(_: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool
    {
        // Swift.print("\(#function)")
        return GIDSignIn.sharedInstance().handle(url as URL?)
    }



    func applicationWillResignActive(_: UIApplication)
    {
        // Swift.print("\(#function)")

        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_: UIApplication)
    {
        // Swift.print("\(#function)")

        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_: UIApplication)
    {
        // Swift.print("\(#function)")

        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_: UIApplication)
    {
        // Swift.print("\(#function)")

        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_: UIApplication)
    {
        // Swift.print("\(#function)")

        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    // MARK: -
    
    
//    Sign out the user
//
//    You can use the signOut method of the GIDSignIn object to sign out your user on the current device, for example:
//
//    @IBAction func didTapSignOut(_ sender: AnyObject) {
//        GIDSignIn.sharedInstance().signOut()
//    }
}

@available(iOS 13.0, *)
extension AppDelegate: GIDSignInDelegate
{
    func sign(_: GIDSignIn!,
              didSignInFor user: GIDGoogleUser!,
              withError error: Error!)
    {
        // Swift.print("\(#function)")

        if error != nil
        {
            // Swift.print("Error: GIDSignIn: \(error)")
            // Perform any operations on signed in user here.
            print("GIDSignIn: \(error.localizedDescription)") //   todo ignore Cancel
            // ...
        }
        else
        {
            let userId: String = user.userID // For client-side use only!
            let idToken: String = user.authentication.idToken // Safe to send to the server
            let fullName: String = user.profile.name
//            let givenName: String = user.profile.givenName
//            let familyName: String = user.profile.familyName
            let email: String = user.profile.email
          
            Swift.print("\(userId), \(idToken), \(fullName), \(email)")
            // todo what to save
            Swift.print("GIDSignIn \(user!), what todo with result?")
        }
    }
    
}

