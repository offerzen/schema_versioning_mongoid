
# namespace :schema_version do
#   require_relative '../schema_versioning_mongoid/utilities'
#   include SchemaVersioningMongoid::Utilities

#   require 'securerandom'
#   require 'json'
#   require 'yaml'

#   def display_message(message, message_type = :info)
#     color_code =
#       case message_type
#       when :info then "\e[34m" # Blue
#       when :success then "\e[32m" # Green
#       when :warning then "\e[33m" # Yellow
#       when :error then "\e[31m" # Red
#       else "\e[0m" # Default
#       end

#     puts "#{color_code}#{message}\e[0m"
#   end

#   desc "Check if the schema of a Mongoid model matches the schema in schema_versions.yml"
#   task :check, [:relative_path] => :environment do |t, args|
#     full_path, class_name, klass = validate_path_and_class(args)

#     if full_path.nil? || class_name.nil? || klass.nil?
#       display_message("Could not validate the class. Make sure it's a Mongoid document and the path is correct.", :error)
#       exit 1
#     end

#     check_result = check_schema(full_path, class_name, klass)

#     if check_result[:result]
#       display_message("Schema for #{class_name} matches the schema in #{schema_file}", :success)
#     else
#       display_message("Schema for #{class_name} DOES NOT match the schema in #{schema_file}", :error)
#     end

#     if check_result[:warnings]
#       check_result[:warnings].each { |warning| display_message(warning, :warning) }
#     end
#   end

#   desc "Set SCHEMA_VERSION for a Mongoid model"
#   task :set, [:relative_path] => :environment do |t, args|
#     full_path, class_name, klass = validate_path_and_class(args)

#     last_schema_record = find_last_schema(klass.name)
#     current_schema = convert_type(klass)
#     current_uuid = klass.const_get('SCHEMA_VERSION') rescue nil

#     if (last_schema_record && last_schema_record[:fields] == current_schema)
#       if last_schema_record[:uuid] != current_uuid
#         display_message "Schema has not changed, but UUID has for #{klass.name}. Please verify if UUID change was intentional."
#         next
#       else
#         display_message "Schema and UUID have not changed for #{klass.name}. Skipping update."
#         next
#       end
#     end

#     uuid = write_new_schema_version(full_path, class_name)
#     write_to_schema_file(uuid, klass, current_schema)
#   end

#   def write_new_schema_version(full_path, class_name)
#     uuid = SecureRandom.uuid
#     content = File.read(full_path)

#     if schema_version_present?(content)
#       new_content = update_existing_schema_version(content, uuid)
#       display_message(".", :success)
#     else
#       new_content = insert_new_schema_version(content, uuid)
#     end
#     File.write(full_path, new_content)

#     uuid
#   end

#   def schema_version_present?(content)
#     !content.scan(/SCHEMA_VERSION/).empty?
#   end
  
#   def update_existing_schema_version(content, uuid)
#     content.gsub(/(SCHEMA_VERSION\s*=\s*)'[^']*'/, "SCHEMA_VERSION = '#{uuid}'")
#   end
  
#   def insert_new_schema_version(content, uuid)
#     pattern = /include Mongoid::Document/
#     if content.scan(pattern).empty?
#       class_definition_pattern = /(class\s+[A-Za-z0-9_:]+(\s*<\s*[A-Za-z0-9_:]+)?)(\n|\s+)/
#       "\\1\n  SCHEMA_VERSION = '#{uuid}'\\3"
#     else
#       "include Mongoid::Document; SCHEMA_VERSION = '#{uuid}'"
#     end
#   end

#   def write_to_schema_file(uuid, klass, current_schema)
#     timestamp = Time.now.utc.iso8601
#     schema_data = {
#       timestamp: timestamp,
#       uuid: uuid,
#       model_name: klass.name,
#       fields: current_schema
#     }

#     File.open(schema_file, 'a') do |f|
#       f.write(schema_data.to_yaml)
#     end
#   end

#   def perform_check(full_path, class_name, klass)
#     schema_check_result = check_schema(full_path, class_name, klass)
#     puts schema_check_result[:warnings]
    
#     if !schema_check_result[:result]
#       Rake::Task["schema_version:set"].invoke(full_path)
#     end
#   end

#   # Example: 
#   #  ```
#   #  $ rake schema_version:run_all['concerns,history_tracker,api_token']
#   #  ```
#   desc "Run check and set tasks for all Mongoid models, exlude with ['filepath,patterns,to,reject]"
#   task :run_all, [:reject_patterns] => :environment do |t, args|
#     reject_patterns = args[:reject_patterns] ? args[:reject_patterns].split(',') : []

#     model_files = Dir["#{Rails.root}/app/models/**/*.rb"]
#       .reject { |item| reject_patterns.any? { |pattern| item.include?(pattern) } }

#     model_files.each do |model_file|
#       require model_file

#       relative_path = model_file.sub("#{Rails.root}/app/models/", "")
#       full_path, class_name, klass = validate_path_and_class({ relative_path: relative_path })

#       next unless klass && klass.included_modules.include?(Mongoid::Document)

#       perform_check(full_path, class_name, klass)
      
#       # Indicate progress
#       display_message('.', :success)
#     end
#   end
# end
