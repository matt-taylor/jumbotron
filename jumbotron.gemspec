# frozen_string_literal: true

require_relative "lib/jumbotron/version"

Gem::Specification.new do |spec|
  spec.name = "jumbotron"
  spec.version = Jumbotron::VERSION
  spec.authors = ["matt-taylor"]
  spec.email = [""]
  spec.homepage = "https://github.com/matt-taylor/jumbotron"
  spec.summary = "Jumbotron is the backend sports-truth Rails Engine."
  spec.description = "Jumbotron owns canonical sports truth independently of ESPN and Pick'em."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,db,lib,docs}/**/*", "spec/factories/**/*", "MIT-LICENSE", "README.md"]
  end

  spec.add_dependency "command_tower", ">= 0.11"
  spec.add_dependency "rails", ">= 7.0", "< 9.0"
end
