
use_frameworks!

def pods
  pod 'Quick', '~> 0.3.1'
  pod 'Nimble', '~> 1.0.0-rc.1'
end

target 'RecTests', :exclusive => true do
  platform :ios, '8.0'
  pods
end

target 'Rec-OSXTests', :exclusive => true do
  platform :osx, '10.10'
  pods
end

