Pod::Spec.new do |s|

  s.name         = "APPromise"
  s.version      = "1.0.0"
  s.summary      = "Promises/A+ implementation."

  s.homepage     = "https://github.com/apleshkov/promises-aplus"

  s.license      = 'MIT'

  s.author       = { "Andrew Pleshkov" => "andrew.pleshkov@gmail.com" }

  s.ios.deployment_target = '5.0'
  s.osx.deployment_target = '10.7'

  s.source       = { :git => "git@github.com:apleshkov/promises-aplus.git", :tag => "1.0.0" }

  s.source_files  = 'APPromise/APPromise/**/*.{h,m}'
  s.public_header_files = 'APPromise/APPromise/**/*.h'

  s.framework  = 'Foundation'
  
  s.requires_arc = true

end
