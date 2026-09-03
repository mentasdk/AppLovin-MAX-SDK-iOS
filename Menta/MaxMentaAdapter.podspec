Pod::Spec.new do |s|
  s.name        = 'MaxMentaAdapter'
  s.version     = '1.0.34'
  s.summary     = 'Menta Global custom adapter for the AppLovin MAX SDK.'
  s.description = 'Supports banner/MREC, interstitial, rewarded, app open, native express, and native self-render ads.'
  s.homepage    = 'https://www.advlion.com'
  s.license     = { :type => 'Custom', :text => 'Copyright Menta. All rights reserved.' }
  s.author      = { 'Menta' => 'mentasdk.vip@gmail.com' }
  
  s.ios.deployment_target = '11.0'
  s.requires_arc      = true
  s.static_framework  = true
  
  s.source              = { :git => 'https://github.com/mentasdk/AppLovin-MAX-SDK-iOS.git', :tag => s.version.to_s }
  s.source_files        = 'MaxMentaAdapter/**/*.{h,m}'
  s.public_header_files = 'MaxMentaAdapter/*.h'
  
  s.dependency 'AppLovinSDK',             '>= 13.0.0'
  s.dependency 'MentaBaseGlobal',         '1.0.34'
  s.dependency 'MentaMediationGlobal',    '1.0.34'
  s.dependency 'MentaVlionGlobal',        '1.0.34'
  s.dependency 'MentaVlionGlobalAdapter', '1.0.34'
  
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '-ObjC'
  }
end
