#
# Be sure to run `pod lib lint MatchingEngine.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'MatchingEngine'
  s.version          = '1.4.2.2'
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
  s.license          = { :type => 'Apache.LICENSE-2.0', :file => 'LICENSE' }
  s.author           = { 'mobiledgex' => 'github@github.com' }
  s.source           = { :git => 'https://github.com/mobiledgex/MatchingEngineSDK.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/mobiledgex'

  s.ios.deployment_target = '11.4'

  s.source_files = 'MatchingEngine/Classes/**/*'
  
  s.dependency 'NSLogger/Swift'
  s.dependency 'Alamofire'
  s.dependency 'SwiftyJSON'
  s.dependency 'PromisesSwift'
  
  # s.resource_bundles = {
  #   'MatchingEngine' => ['MatchingEngine/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'

  s.swift_version = '4.2'
end
