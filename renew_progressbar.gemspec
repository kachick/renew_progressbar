Gem::Specification.new do |gem|
  gem.authors     = ['Satoru Takabayashi', 'Jose Peleteiro', 'Kenichi Kamiya']
  gem.email       = ['satoru@0xcc.net', 'jose@peleteiro.net', 'kachick1+ruby@gmail.com']
  gem.homepage    = 'https://github.com/kachick/renew_progressbar'
  gem.summary     = "Ruby/ProgressBar is a text progress bar library for Ruby."
  gem.description = "Ruby/ProgressBar is a text progress bar library for Ruby. It can indicate progress with percentage, a progress bar, and estimated remaining time."

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})  
  gem.name        = 'renew_progressbar'
  gem.require_paths = ['lib']
  gem.version     = ProgressBar::VERSION.dup

  gem.required_ruby_version = '>= 1.9.2'

  gem.add_development_dependency 'yard', '~> 0.8'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'bundler'
end
