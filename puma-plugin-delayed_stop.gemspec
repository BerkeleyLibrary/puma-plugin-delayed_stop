# frozen_string_literal: true

require_relative "lib/puma/plugin/delayed_stop/version"

Gem::Specification.new do |spec|
  spec.name = "puma-plugin-delayed_stop"
  spec.version = PumaPluginDelayedStop::VERSION
  spec.authors = ["Dan Schmidt"]
  spec.email = ["danschmidt5189@berkeley.edu"]
  spec.summary = "Puma plugin that delays shutdown for graceful container draining"
  spec.description = <<~DESC
    A Puma plugin that intercepts a configurable signal (default: SIGQUIT) and
    waits a configurable number of seconds before telling Puma to stop. This
    gives orchestrators like Kubernetes and Docker Swarm time to remove the
    container from load balancing before connections are closed.
  DESC
  spec.homepage = "https://github.com/BerkeleyLibrary/puma-plugin-delayed_stop"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "LICENSE", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "puma", ">= 5.0", "< 8"

  spec.add_development_dependency "bundler", ">= 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
