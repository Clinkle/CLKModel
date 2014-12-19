Pod::Spec.new do |s|
  s.name             = "CLKModel"
  s.version          = "0.1.0"
  s.summary          = "CLKModel provides an excellent for your iOS app's data layer."
  s.homepage         = "https://github.com/Clinkle/CLKModel"
  s.license          = 'MIT'
  s.author           = { "tsheaff" => "tyler@clinkle.com" }
  s.source           = { :git => "ssh://git@github.com/Clinkle/CLKModel.git", :tag => s.version.to_s }

  s.dependency 'ObjectiveSugar', '~> 1.1.0'
  s.frameworks = 'Security'

  s.platform     = :ios, '7.0'
  s.requires_arc = true
  s.source_files = 'Pod/Classes'
end
