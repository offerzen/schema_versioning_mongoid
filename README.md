# Schema Versioning Pattern for Mongoid

MongoDB recommends the schema versioning pattern to enable 
downstream consumers of data records understand its contents.

https://www.mongodb.com/blog/post/building-with-patterns-the-schema-versioning-pattern

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
The inline strategy is available should you want your SCHEMA_VERSION to be a visible constant inside each model for added visibility and awareness. Though, this may be cumbersome for some.

### Centralized Strategy (default)
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
run the rake tasks below, for example: `rake schema_version:run_all reject_patterns='concerns,history_tracker'`




## Rake Tasks
This task checks if the schema versions in your Mongoid models match the ones in the centralized YAML file. This is particularly useful in CI/CD pipelines to ensure that your schemas are up-to-date.

If you're using the centralized approach for schema versioning, this task will initialize a YAML file to store all the schema versions.
### Initialization
`rake db:mongoid:init_schema_versioning`
This task initializes an empty schema_versions.yml file. This file will hold the schema versions for each Mongoid model in your application.

Run the task as follows:

```sh
rake db:mongoid:init_schema_versioning
```

### Check Schema Version
`rake db:mongoid:check_schema_version[relative_path]`
This task checks if the schema of a specified Mongoid model matches the schema listed in schema_versions.yml.

`relative_path`: The relative path to the model's Ruby file, starting from the models directory.

Example:

```sh
rake db:mongoid:check_schema_version[user.rb]
```

### Set Schema Version
`rake db:mongoid:set_schema_version[relative_path]`
Sets or updates the SCHEMA_VERSION constant for a specified Mongoid model.

`relative_path`: The relative path to the model's Ruby file, starting from the app/models/ directory.
Example:

```sh
rake db:mongoid:set_schema_version[user.rb]
```

### Update All Schema Versions
`rake db:mongoid:update_schema_versions[reject_patterns]`
This task will run the check_schema_version and set_schema_version tasks for all Mongoid models in your application, excluding models that match any of the patterns specified.

reject_patterns: Comma-separated string of patterns to reject. These should be substrings that might appear in the file path of models you wish to exclude.

Example:

```sh
rake db:mongoid:update_schema_versions reject_patterns='concerns,history_tracker,api_token'
```

### Validate All Schema Versions
`rake db:mongoid:validate_schema_versions`
This task will validate the schema of all Mongoid models against schema_versions.yml without modifying them.

Example:

```sh
rake db:mongoid:validate_schema_versions
```

## Model Schema Version Validator and Diff Tool
<img width="604" alt="image" src="https://github.com/offerzen/schema_versioning_mongoid/assets/3964065/cd09fd8e-eecc-49db-9b77-4341934c9d04">
### Overview
The schema version validator and diff tool is a utility that allows developers to compare the current version of a MongoDB model schema with its historical versions. This can be useful for understanding changes, migrations, or potential compatibility issues in the system.

### Installation
This tool is bundled as a Rake task within your Rails application. Make sure you have updated to the latest version of the application that includes this tool.

### Requirements
- Ruby on Rails environment
- MongoDB
- Access to `db/schema_versions_centralized.yml` and `db/schema_versions.yml` files.

### Usage
Run the Rake task using the following command to validate schema versions and display differences:

```bash
rake db:mongoid:validate_schema_versions_with_diff MODEL=YourModelName
```
Replace `YourModelName` with the model name you'd like to validate. If you don't specify a model name, it defaults to 'Users'.

#### Sample Output
The output will provide you with a detailed comparison between the current and historical versions of the specified model, formatted similarly to GitHub diffs:

```markdown
Differences for model: YourModelName
Comparing with Version 1 [timestamp uuid]:
  + added_field_1
  + added_field_2
  - removed_field
  ~ changed_field
```
- Lines with `+` indicate fields that have been added in the current version.
- Lines with `-` indicate fields that have been removed in the current version.
- Lines with `~` indicate fields whose types have changed in the current version.

## Usage
- Initialize schema versioning by running `rake db:mongoid:init_schema_versioning`.
- Set or update the schema version for individual models with `rake db:mongoid:set_schema_version[relative_path]`.
- Check if a model's schema matches the schema version with `rake db:mongoid:check_schema_version[relative_path]`.
- Update the schema versions for all models with `rake db:mongoid:update_schema_versions[reject_patterns]`.
- Validate all models' schemas with `rake db:mongoid:validate_schema_versions`.
- Visualize schemas version difference with `rake db:mongoid:diff`.

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
