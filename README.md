# MatchingEngine

[![CI Status](https://img.shields.io/travis/lgarner/MatchingEngine.svg?style=flat)](https://travis-ci.org/lgarner/MatchingEngine)
[![Version](https://img.shields.io/cocoapods/v/MatchingEngine.svg?style=flat)](https://cocoapods.org/pods/MatchingEngine)
[![License](https://img.shields.io/cocoapods/l/MatchingEngine.svg?style=flat)](https://cocoapods.org/pods/MatchingEngine)
[![Platform](https://img.shields.io/cocoapods/p/MatchingEngine.svg?style=flat)](https://cocoapods.org/pods/MatchingEngine)


The MobiledgeX Client Library enables an application to register and then locate the nearest edge cloudlet backend server for use. The client library also allows verification of a device's location for all location-specific tasks. Because these APIs involve networking, most functions will run asynchronously, and in a background thread, utilizing the Google Promises framework and iOS DispatchQueue.

The Matching Engine iOS SDK provides everything required to create applications for iOS devices.


## Prerequisites  

* MacOS Mojave installation
* Xcode 10 (From the Apple store, search for **Xcode**)
* An Apple ID. Create an ID from the developer site on [Apple](https://developer.apple.com)
* An iOS device to test with
* [Cocoapods](https://cocoapods.org) installation

## Download the iOS SDK and libraries  

Step 1: Create a login and an Organization on the [Console](https://console.mobiledgex.net). The creation of a login will automatically generate a user account and allows for access to [Artifactory](https://artifactory.mobiledgex.net).  

**Note**: With a login, you can download the iOS SDK library as well as upload a server image to install on the edge network.  

Step 2: In terminal, run these commands to install Cocoapods: ```gem install cocoapods``` and ```gem install cocoapods-art```.  

Step 3: Go to your root directory ```cd ~```.

Step 4: Create a .netrc file and enter the following credentials: ```echo machine artifactory.mobiledgex.net login <username> password
<password> .netrc```. Use the same credentials created on the Console in Step 1.

Step 5: Navigate to your project directory and add the following lines to your podfile:  

* ```plugin 'cocoapods-art', :sources =>; ['cocoapods-releases']```
* ```pod 'MobiledgeXiOSLibrary', '= 2.1.0'```  

Example podfile:
```
use_frameworks!
platform :ios, '12.0'
# Default Specs.git:
source 'https://github.com/CocoaPods/Specs.git'
plugin 'cocoapods-art', :sources => ['cocoapods-releases']
target 'ARShooter' do  
pod 'MobiledgeXiOSLibrary','= '2.1.0'
end
```
Step 6: Save your podfile, and then run the following command to install the MobiledgeXLibarary dependency to your workspace: ```pod install```.

Step 7: Open your xcworkspace.

Step 8: Copy and paste ```import MobiledgeXiOSLibrary``` in any file(s) where you will utilize the MobiledgeX libary/SDK.  

### Where to Go from Here  
* Click [here](https://swagger.mobiledgex.net/client-test/#section/Edge-SDK-iOS) to view and familiarize yourself with the iOS SDK APIs and start your MobiledgeX integration.

* Need a sample app? Click [here](https://github.com/mobiledgex/edge-cloud-sampleapps/tree/master/iOS/ARShooterExample) to see an example application that uses the MobiledgeXiOSLibrary, and [here](https://developers.mobiledgex.com/guides-and-tutorials/how-to-add-edge-support-to-an-ios-argame) to access instructions to get started.

* To learn how to use Docker to upload your application, see this [tutorial](https://developers.mobiledgex.com/guides-and-tutorials/hello-world).

## Author

mobiledgex, MatchingEngineSDK@mobiledgex.com

## License

MatchingEngineSDK is available under the Apache.LICENSE-2.0. See the LICENSE file for more info.

Copyright (C) 2019-2020 MobiledgeX, Inc.

Multiple licenses (MIT, BSD, Apache, etc.) for third-party components.
