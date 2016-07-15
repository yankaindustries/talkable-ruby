$:.push File.expand_path('../lib', __FILE__)
require 'talkable/version'

Gem::Specification.new do |s|
  s.name        = "talkable"
  s.version     = Talkable::VERSION
  s.date        = Date.today.to_s
  s.summary     = "Talkable Referral Programe API"
  s.description = "Talkable Ruby Gem to make your own referral program in Sinatra or Rails application"
  s.authors     = ["Talkable"]
  s.email       = "dev@talkable.com"
  s.homepage    = "https://github.com/talkable/talkable-ruby"
  s.license     = 'MIT'

  s.files         = `git ls-files`.split("\n").reject { |f| f.match(%r{^(test|spec|features)/}) }
  s.require_paths = ["lib"]

  s.add_development_dependency "bundler", "~> 1.12"
  s.add_development_dependency "rake", "~> 11.2"
  s.add_development_dependency "rspec", "~> 3.4"
  s.add_development_dependency "simplecov", "~> 0.12"
end
