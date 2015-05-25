Pod::Spec.new do |s|
  s.name             = "Rec"
  s.version          = "1.0.1"
  s.summary          = "Helper library to record URL requests and save them locally (great for fixtures in HTTP stubbing)."
  s.description      = <<-DESC
Rec is a `NSURLProtocol` that intercepts each `NSURL` request made from `NSURLSession`s (with `defaultSessionConfiguration` & `ephemeralSessionConfiguration`) and adds itself as the delegate for the connection; once the request succeeds the framework will save it to the application's `Documents` folder (under «Fixtures» folder).
                       DESC
  s.homepage         = "https://github.com/esttorhe/Rec"
  s.license          = 'MIT'
  s.author           = { "esttorhe" => "me@estebantorr.es" }
  s.source           = { :git => "https://github.com/esttorhe/Rec.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/esttorhe'
  s.requires_arc = true
  
  s.source_files = 'Rec/*.swift'
  s.dependency 'Result', '~> 0.4'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.9'
  s.module_name = 'Rec'
end
