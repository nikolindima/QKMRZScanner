Pod::Spec.new do |s|
  s.name     = "QKMRZScanner"
  s.version  = "3.0.0"
  s.platform = :ios, "11"
  s.swift_version = "4.2"

  s.summary  = "Scans MRZ (Machine Readable Zone) from identity documents (passport, id, visa)."
  s.author   = { "Matej Dorcak" => "sss.mado@gmail.com" }
  s.homepage = "https://github.com/Mattijah/QKMRZScanner"
  s.license  = { :type => "MIT", :file => "LICENSE" }

  s.source   = { :git => "https://github.com/Mattijah/QKMRZScanner.git", :tag => "v#{s.version}" }
  s.source_files = "QKMRZScanner/**/*.{swift}"
  s.frameworks   =  "Foundation", "UIKit", "AVFoundation", "CoreImage", "AudioToolbox"
  
end
