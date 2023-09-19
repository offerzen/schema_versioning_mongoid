# frozen_string_literal: true

require_relative "lib/schema_versioning_mongoid/version"

Gem::Specification.new do |spec|
  spec.name = "schema_versioning_mongoid"
  spec.version = SchemaVersioningMongoid::VERSION
  spec.authors = ["OfferZen"]
  spec.email = ["hello@offerzen.com"]

  spec.summary = "Schema Versioning pattern for Mongoid"
  spec.description = <<-DESC 
    MongoDB recommends the schema versioning pattern to enable 
    downstream consumers of data records understand its contents.

    https://www.mongodb.com/blog/post/building-with-patterns-the-schema-versioning-pattern
  DESC
  spec.homepage = "https://github.com/offerzen"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  # spec.metadata["source_code_uri"] = "https://github.com/offerzen"
  spec.metadata["changelog_uri"] = "https://github.com/offerzen"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "railties", "~> 6.0"
  spec.add_dependency "rails", "~> 6.0"
  spec.add_dependency "mongoid", "~> 7.0"
  spec.add_dependency 'pastel'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
