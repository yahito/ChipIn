platform :ios, '16.0'

target 'ChipIn' do
  use_frameworks!

  # Firebase dependencies
  pod 'Firebase/Core', '~> 10.22.0'
  pod 'Firebase/Analytics', '~> 10.22.0'
  pod 'FirebaseAuth', '~> 10.22.0'
  pod 'FirebaseStorage', '~> 10.22.0'
  pod 'FirebaseFirestore', '~> 10.22.0'
  pod 'Google-Mobile-Ads-SDK'
  pod 'GoogleSignIn', '~> 7.0.0' # Use the latest version of GoogleSignIn
end


post_install do |installer|
  installer.pods_project.targets.each do |target|
    if target.name == 'BoringSSL-GRPC'
      target.source_build_phase.files.each do |file|
        if file.settings && file.settings['COMPILER_FLAGS']
          flags = file.settings['COMPILER_FLAGS'].split
          flags.reject! { |flag| flag == '-GCC_WARN_INHIBIT_ALL_WARNINGS' }
          file.settings['COMPILER_FLAGS'] = flags.join(' ')
        end
      end
    end
  end
end