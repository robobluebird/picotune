Gem::Specification.new do |s|
  s.name        = 'picotune'
  s.version     = '0.0.7'
  s.summary     = "Text file -> wav file. Make tiny tunes!"
  s.description = "Use a text file with a simple DSL to generate a musical (maybe) wav file. See https://github.com/robobluebird/picotune for DSL documentation!"
  s.authors     = ["Zachary Schroeder"]
  s.email       = 'schroza@gmail.com'
  s.files       = ["lib/picotune.rb"]
  s.homepage    = 'https://github.com/robobluebird/picotune'
  s.license     = 'MIT'
  s.metadata = {
    "documentation_uri" => "https://github.com/robobluebird/picotune",
    "homepage_uri"      => "https://github.com/robobluebird/picotune",
    "source_code_uri"   => "https://github.com/robobluebird/picotune",
  }

  s.executables << 'picotune'

  s.add_dependency "wavefile", "~> 1.1.1"
end
