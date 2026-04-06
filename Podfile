platform :ios, '16.0'

target 'Scanner' do
  use_frameworks!

  # Layout
  pod 'SnapKit'
  pod 'SVProgressHUD'

  # Database
  pod 'WCDBSwift'

  # Networking
  pod 'Moya'
  
  # Image Processing
  pod 'OpenCV', '~> 4.3.0'
  
  # Encryption
  pod 'CryptoSwift'
  
  # OSS Upload
  pod 'AliyunOSSiOS'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      config.build_settings.delete('EXCLUDED_ARCHS[sdk=iphonesimulator*]')
    end
  end

  # Remove arm64 simulator exclusion from aggregate xcconfigs (Apple Silicon fix)
  Dir.glob(File.join(installer.sandbox.root, 'Target Support Files', '**', '*.xcconfig')).each do |xcconfig_path|
    content = File.read(xcconfig_path)
    updated = content.gsub(/EXCLUDED_ARCHS\[sdk=iphonesimulator\*\]\s*=\s*arm64/, '')
    File.write(xcconfig_path, updated)
  end
end
