#
# Be sure to run `pod lib lint OverTheEther.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'OverTheEther'
  s.version          = '0.3.0'
  s.summary          = 'Send data between devices'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
This library allows you to send any kind of data between iOS and macOS devices via Bluetooth or WiFi, without much hassle.
                       DESC

  s.homepage         = 'https://github.com/JojoSc/OverTheEther'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'JojoSc' => 'mail@jsap.net' }
  s.source           = { :git => 'https://github.com/JojoSc/OverTheEther.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'OverTheEther/Classes/**/*'
  
  # s.resource_bundles = {
  #   'OverTheEther' => ['OverTheEther/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.dependency 'CocoaLumberjack/Swift'
  s.dependency 'CocoaAsyncSocket'
  s.dependency 'Parse'
end
