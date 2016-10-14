Pod::Spec.new do |s|
  s.name             = 'SPAsyncVideoView'
  s.version          = '0.4.5'
  s.summary          = 'Smooth asynchronous video view. Perfect for autoplay & loop videos/GIFs in UITableView/UICollectionView.'
  s.description      = <<-DESC
                        Smooth asynchronous video view. Perfect for autoplay & loop videos/GIFs in UITableView/UICollectionView..
                        Can play GIFs/videos with low memory footprint and on 60fps.
                       DESC
  s.homepage         = 'https://github.com/xquezme/SPAsyncVideoView'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Pimenov Sergey' => 'pimenov.sergei@gmail.com' }
  s.source           = { :git => 'https://github.com/xquezme/SPAsyncVideoView.git', :tag => s.version.to_s }
  s.ios.deployment_target = '8.0'
  s.source_files = 'SPAsyncVideoView/Classes/**/*'
  s.public_header_files = 'SPAsyncVideoView/Classes/**/*.h'
  s.frameworks = 'UIKit', 'Foundation', 'AVFoundation', 'ImageIO', 'MobileCoreServices'
  s.requires_arc = true
end
