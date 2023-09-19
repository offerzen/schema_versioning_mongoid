require 'securerandom'
require 'json'
require 'yaml'
require_relative '../schema_versioning_mongoid/utilities'
require_relative '../schema_versioning_mongoid/strategies'

module SchemaVersioningMongoid
  module Display
    def display_message(message, message_type = :info)
      color_code =
        case message_type
        when :info then "\e[34m" # Blue
        when :success then "\e[32m" # Green
        when :warning then "\e[33m" # Yellow
        when :error then "\e[31m" # Red
        else "\e[0m" # Default
        end

      print "#{color_code}#{message}\e[0m"
    end
  end
end

namespace :"db:mongoid" do
  include SchemaVersioningMongoid::Utilities
  include SchemaVersioningMongoid::Display

  desc "Check if the schema of a Mongoid model matches the schema in schema_versions.yml"
  task :check_schema_version, [:relative_path] => :environment do |t, args|
    full_path, class_name, klass = validate_path_and_class(args)
    exit_unless_valid_class(full_path, class_name, klass)
    perform_and_display_check(full_path, class_name, klass)
  end

  desc "Set SCHEMA_VERSION for a Mongoid model"
  task :set_schema_version, [:relative_path] => :environment do |t, args|
    full_path, class_name, klass = validate_path_and_class(args)

    last_schema_record = find_last_schema(klass.name)
    current_schema = convert_type(klass)
    current_uuid = klass.const_get('SCHEMA_VERSION') rescue nil

    if (last_schema_record && last_schema_record[:fields] == current_schema)
      if last_schema_record[:uuid] != current_uuid
        display_message "Schema has not changed, but UUID has for #{klass.name}. Please verify if UUID change was intentional."
        # Reset the tasks so they can be invoked again
        Rake::Task["db:mongoid:check_schema_version"].reenable
        Rake::Task["db:mongoid:set_schema_version"].reenable
        next
      else
        display_message "Schema and UUID have not changed for #{klass.name}. Skipping update."
        # Reset the tasks so they can be invoked again
        Rake::Task["db:mongoid:check_schema_version"].reenable
        Rake::Task["db:mongoid:set_schema_version"].reenable
        next
      end
    end

    uuid = write_new_schema_version(full_path, class_name)
    write_to_schema_file(uuid, klass, current_schema)
  end

  

  # Example: 
  #  ```
  #  $ rake db:mongoid:update_schema_versions reject_patterns='concerns,history_tracker,api_token'
  #  ```
  desc "Run check and set tasks for all Mongoid models, exclude with ENV VAR rake db:mongoid:update_schema_versions reject_patterns='filepath,patterns,to,reject"
  task :update_schema_versions => :environment do |t, args|
    reject_patterns = ENV['reject_patterns'] ? ENV['reject_patterns'].split(',') : ['concerns', 'history_tracker', 'api_token']

    model_files = Dir["#{Rails.root}/app/models/**/*.rb"]
      .reject { |item| reject_patterns.any? { |pattern| item.include?(pattern) } }

    model_files.each do |model_file|
      require model_file

      relative_path = model_file.sub("#{Rails.root}/app/models/", "")
      full_path, class_name, klass = validate_path_and_class({ relative_path: relative_path })

      next unless klass && klass.included_modules.include?(Mongoid::Document)

      perform_check(full_path, class_name, klass)
      
      # Indicate progress
      display_message('.', :success)
      # Reset the tasks so they can be invoked again
      Rake::Task["db:mongoid:check_schema_version"].reenable
      Rake::Task["db:mongoid:set_schema_version"].reenable
    end
  end

  desc "Initialize the schema_versions.yml file if it doesn't exist"
  task :init_schema_versioning => :environment do
    unless File.exist?(SchemaVersioningMongoid::Utilities.schema_file)
      File.open(SchemaVersioningMongoid::Utilities.schema_file, 'w') do |f|
        f.write({}.to_yaml)
      end
      puts "Initialized empty schema_versions.yml file"
    else
      puts "schema_versions.yml file already exists, skipping initialization"
    end
  end

  desc "Validate all models against the schema file without modifying them"
  task :validate_schema_versions => :environment do |t, args|
    reject_patterns = ENV['reject_patterns'] ? ENV['reject_patterns'].split(',') : ['concerns', 'history_tracker', 'api_token']

    model_files = Dir["#{Rails.root}/app/models/**/*.rb"]
      .reject { |item| reject_patterns.any? { |pattern| item.include?(pattern) } }

    model_files.each do |model_file|
      require model_file

      relative_path = model_file.sub("#{Rails.root}/app/models/", "")
      full_path, class_name, klass = validate_path_and_class({ relative_path: relative_path })

      next unless klass && klass.included_modules.include?(Mongoid::Document)

      schema_check_result = check_schema(full_path, class_name, klass)
      
      if !schema_check_result[:result]
        display_message("Schema for #{class_name} DOES NOT match the schema in #{SchemaVersioningMongoid::Utilities.schema_file}", :error)
      else
        display_message(".", :success)
      end
    end
  end

  # desc "Cleanup old schema versions that are no longer needed"
  # task :cleanup => :environment do
  #   existing_data = YAML.load_file(SchemaVersioningMongoid::Utilities.schema_file)
  #   model_files = Dir["#{Rails.root}/app/models/**/*.rb"].map do |path|
  #     path.sub("#{Rails.root}/app/models/", "").sub(".rb", "").classify
  #   end

  #   updated_data = existing_data.select { |key, _| model_files.include?(key) }

  #   File.open(SchemaVersioningMongoid::Utilities.schema_file, 'w') do |f|
  #     f.write(updated_data.to_yaml)
  #   end

  #   puts "Cleaned up old schema versions"
  # end

  private

  def exit_unless_valid_class(full_path, class_name, klass)
    if full_path.nil? || class_name.nil? || klass.nil?
      display_message("Could not validate the class. Make sure it's a Mongoid document and the path is correct.", :error)
      exit 1
    end
  end

  def perform_and_display_check(full_path, class_name, klass)
    check_result = check_schema(full_path, class_name, klass)

    if check_result[:result]
      display_message(".", :success)
    else
      display_message("Schema for #{class_name} DOES NOT match the schema in #{SchemaVersioningMongoid::Utilities.schema_file}", :error)
    end

    check_result[:warnings]&.each { |warning| display_message(warning, :warning) }
  end

  def write_new_schema_version(full_path, class_name)
    write_strategy = SchemaVersioningMongoid::Strategies::Centralized

    uuid = SecureRandom.uuid
    content = File.read(full_path)

    if schema_version_present?(content)
      
      write_strategy.update(full_path, class_name, uuid, content)
      display_message(".", :success)
    else
      write_strategy.insert(full_path, class_name, uuid, content)
      display_message(".", :success)
    end
    display_message("ACTION: UUID updated for #{class_name}", :success)

    uuid
  end

  def schema_version_present?(content)
    !content.scan(/SCHEMA_VERSION/).empty?
  end
  
  # def update_existing_schema_version(content, uuid)
  #   content.gsub(/(SCHEMA_VERSION\s*=\s*)'[^']*'/, "SCHEMA_VERSION = '#{uuid}'")
  # end
  
  # def insert_new_schema_version(content, uuid)
  #   pattern = /include Mongoid::Document/
  #   if content.scan(pattern).empty?
  #     class_definition_pattern = /(class\s+[A-Za-z0-9_:]+(\s*<\s*[A-Za-z0-9_:]+)?)(\n|\s+)/
  #     replacement = "\\1\n  SCHEMA_VERSION = '#{uuid}'\\3"
  #     content.gsub(class_definition_pattern, replacement)
  #   else
  #     replacement = "include Mongoid::Document; SCHEMA_VERSION = '#{uuid}'"
  #     content.gsub(pattern, replacement)
  #   end
  # end

  def write_to_schema_file(uuid, klass, current_schema)
    timestamp = Time.now.utc.iso8601
    schema_data = {
      timestamp: timestamp,
      uuid: uuid,
      model_name: klass.name,
      fields: current_schema
    }

    File.open(SchemaVersioningMongoid::Utilities.schema_file, 'a') do |f|
      f.write(schema_data.to_yaml)
    end
  end

  def perform_check(full_path, class_name, klass)
    schema_check_result = check_schema(full_path, class_name, klass)
    puts schema_check_result[:warnings]
    
    if !schema_check_result[:result]
      relative_path = full_path.sub("#{Rails.root}/app/models/", "")
      Rake::Task["db:mongoid:set_schema_version"].invoke(relative_path)
    end
  end
end
