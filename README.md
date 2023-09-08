# schema_versioning_mongoid

`schema_versioning_mongoid` is a gem that helps you maintain and version your MongoDB schemas in a Rails application. It allows you to automatically update or insert `SCHEMA_VERSION` constants in your Mongoid models to help track changes.

## Features

- Auto-generation of `SCHEMA_VERSION` constant in your Mongoid models.
- Centralized tracking of schema versions using a YAML file.
- Support for both inline and centralized schema versioning strategies.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'schema_versioning_mongoid'
```

And then execute:

```ruby
$ bundle install
```

## Usage
### Inline Strategy
(TBA: Explain how to use the inline strategy)

### Centralized Strategy
To use the centralized strategy, you will need to create a YAML file to store the schema versions. This can be placed anywhere in your application, although we recommend storing it in the db or config directory. For example, db/schema_versions_centralized.yml.

Sample YAML Content
```yaml
User: "some-uuid"
Product: "another-uuid"
```

### Initializer Code
Add the following initializer code to populate the SCHEMA_VERSION constants from the centralized YAML file. Create a new file `config/initializers/mongoid_document_extension.rb` and add the following lines:

```ruby
# config/initializers/mongoid_document_extension.rb
module Mongoid
  module Document
    # Class method to load schema versions from YAML file and set them as class constants
    def self.load_schema_versions_from_yaml(file_path)
      centralized_schema_versions = YAML.load_file(file_path)
      centralized_schema_versions.each do |klass_name, uuid|
        begin
          klass = klass_name.constantize
          klass.const_set("SCHEMA_VERSION", uuid) unless klass.const_defined?("SCHEMA_VERSION")
        rescue NameError => e
          puts "Could not find class #{klass_name}"
        end
      end
    end

    def self.included(base)
      return unless base.is_a?(Class)
      
      base.field :schema_version, type: String
      base.before_create :set_schema_version
      base.before_update :set_schema_version
      
      # Instance method to set the schema_version field
      base.send(:define_method, :set_schema_version) do
        schema_version_constant = self.class.const_get("SCHEMA_VERSION", false) # false flag will prevent an error if constant is not defined
        self.schema_version = schema_version_constant if schema_version_constant
      end
    end
  end
end

Mongoid::Document.load_schema_versions_from_yaml(Rails.root.join("db", "schema_versions_centralized.yml"))
```

### Update Schema Versions
(TBA: Explain how to update schema versions in either strategy)

## Rake Tasks

This gem provides several Rake tasks to help manage schema versions in your application. Here's a list of the available tasks and their descriptions:

### `rake schema_version:run_all`

This task will go through all your Mongoid models and either update or insert the `SCHEMA_VERSION` constant. You can pass an array of patterns to skip certain folders or file names.

Usage:

```bash
rake "schema_version:run_all['concerns,history_tracker']"
rake "schema_version:check[models_subdirectory/model.rb]"
rake "schema_version:set[models_subdirectory/model.rb]"
```

This task checks if the schema versions in your Mongoid models match the ones in the centralized YAML file. This is particularly useful in CI/CD pipelines to ensure that your schemas are up-to-date.

Usage:

```bash
rake schema_version:check
rake schema_version:init_centralized_file
```

If you're using the centralized approach for schema versioning, this task will initialize a YAML file to store all the schema versions.

Usage:

```bash
rake schema_version:init_centralized_file
```

## Tests (RSpec)

Add this to your test suite to validate all the schema is update to date.

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|

  config.before(:suite) do
    if !SchemaVersioningMongoid::RSpecHelper.check_schemas_and_uuids('concerns,history_tracker')
      puts "\nERROR: Schemas and/or UUIDs are not up-to-date!\n"
      exit(1)
    end
  end
```


## Contributing
1. Fork it ( https://github.com/offerzen/schema_versioning_mongoid/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## License
The gem is available as open-source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
