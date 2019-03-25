# -*- encoding: utf-8 -*-
require File.expand_path('../lib/acts_as_network/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Zetetic LLC (Stephen Lombardo), David Kennedy"]
  gem.email         = ["david.kennedy@examtime.com"]
  gem.description   = %q{Simplify the definition and storage of "network" relationships, especially useful for social networks.}
  gem.summary       = %q{Simplify social network relationships}
  gem.homepage      = "https://github.com/ExamTime/acts_as_network"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "acts_as_network"
  gem.require_paths = ["lib"]
  gem.version       = ActsAsNetwork::VERSION

  gem.add_development_dependency "minitest"
  gem.add_development_dependency "byebug"
  gem.add_development_dependency "sqlite3-ruby"
  gem.add_dependency "rails", ">= 3.2.0", "< 6.0"

end
