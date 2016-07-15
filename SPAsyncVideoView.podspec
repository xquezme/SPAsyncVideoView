#
# Be sure to run `pod lib lint SPAsyncVideoView.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SPAsyncVideoView'
  s.version          = '0.1.0'
  s.summary          = 'Smooth asynchronous video view. Perfect for autoplay & loop videos in UITableView/UICollectionView.'
  s.homepage         = 'https://github.com/xquezme/SPAsyncVideoView'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Pimenov Sergey' => 'pimenov.sergei@gmail.com' }
  s.source           = { :git => 'https://github.com/xquezme/SPAsyncVideoView.git', :tag => s.version.to_s }
  s.ios.deployment_target = '8.0'
  s.source_files = 'SPAsyncVideoView/Classes/**/*'
  s.public_header_files = 'SPAsyncVideoView/Classes/**/*.h'
  s.frameworks = 'UIKit', 'MapKit', 'Foundation', 'AVFoundation'
end
