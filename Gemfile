source 'https://rubygems.org'

# Specify your gem's dependencies in mobilize-bash.gemspec
gemspec

group :test, :development do
  if File.exists? File.expand_path("../../mobilize-base", __FILE__)
    gem 'mobilize-base', path: File.expand_path("../../mobilize-base", __FILE__)
  end
end
