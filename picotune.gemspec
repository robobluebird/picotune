Gem::Specification.new do |s|
  s.name        = 'picotune'
  s.version     = '0.0.3'
  s.summary     = "Text file -> wav file. Make tiny tunes!"
  s.description = "Use a text file with a simple DSL to generate a musical (maybe) wav file."
  s.authors     = ["Zachary Schroeder"]
  s.email       = 'schroza@gmail.com'
  s.files       = ["lib/picotune.rb"]
  s.homepage    = 'https://rubygems.org/gems/picotune'
  s.license     = 'MIT'

  s.executables << 'picotune'

  s.add_dependency "wavefile", "~> 1.1.1"
end
