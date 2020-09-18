# BlueSocket minimum-supported ios version is 10.0.
platform :ios, '10.0'

target 'PcVolumeControl' do
    # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
    use_frameworks!
    pod 'RxSwift',    '~> 5'
    pod 'RxCocoa',    '~> 5'
    pod 'BlueSocket'
    
    # Pods for PcVolumeControl
    
    target 'PcVolumeControlTests' do
        inherit! :search_paths
        # Pods for testing
        pod 'RxBlocking', '~> 5'
        pod 'RxTest',     '~> 5'
        pod 'BlueSocket'
    end
    
    target 'PcVolumeControlUITests' do
        inherit! :search_paths
        # Pods for testing
        pod 'RxBlocking', '~> 5'
        pod 'RxTest',     '~> 5'
        pod 'BlueSocket'
    end
    
end
