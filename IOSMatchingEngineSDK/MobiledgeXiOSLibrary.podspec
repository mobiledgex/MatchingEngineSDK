#
# Be sure to run `pod lib lint MobiledgeXiOSLibrary.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name 	     = 'MobiledgeXiOSLibrary' 
  s.version          = '2.0.3'
  s.summary          = 'The MobiledgeX SDK for iOS Swift provides Swift APIs that allows developers to communicate to MobiledgeX service infrastructure'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

s.description      = <<-DESC
Are you excited to connect to MobiledgeX Cloudlet Infrastructure and leverage the power that Mobile Edge Cloud offers? The MobiledgeX SDK for iOS Swift exposes various services that MobiledgeX offers such as finding the nearest MobiledgeX Cloudlet Infrastructure for client-server communication or workload processing offload.
                     DESC

  s.homepage         = 'https://github.com/mobiledgex/MatchingEngineSDK'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'Apache.LICENSE-2.0', :file => 'LICENSE.txt' }
  s.author           = { 'mobiledgex' => 'github@github.com' }
  s.source           = { :git => 'https://github.com/mobiledgex/MatchingEngineSDK.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/mobiledgex'

  s.ios.deployment_target = '11.4'

  s.source_files = 'MobiledgeXiOSLibrary/Classes/**/*'  
 
  s.dependency 'SwiftyJSON', '~> 5.0.0'
  s.dependency 'PromisesSwift', '~> 1.2.8'
  s.dependency 'Socket.IO-Client-Swift', '~> 15.2.0'
  
  s.swift_version = '4.2'
end
