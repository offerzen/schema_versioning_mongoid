module SchemaVersioningMongoid
  module Utilities
    extend self

    # The client can change this with: 
    #   SchemaVersioningMongoid::Utilities.schema_file = 'your_new_path.yml'
    @schema_file = 'db/schema_versions.yml'

    def schema_file
      @schema_file
    end

    def schema_file=(file)
      @schema_file = file
    end

    def convert_type(ttype)
      schema = ttype.fields.each_with_object({}) do |(key, field), hash|
        field_type = field.options[:type]
    
        # Check if the field has an association (relationship)
        if field.options[:association]
          class_name = field.options[:association].options[:class_name]
          hash[key] = class_name
        elsif field_type.respond_to?(:fields) # Custom type
          hash[key] = convert_type(field_type)
        else
          hash[key] = field_type.to_s
        end
      end
      schema
    end

    def all_schemas
      begin
        YAML.load_stream(File.read(SchemaVersioningMongoid::Utilities.schema_file)).compact
      rescue => e
        puts "ERROR: unable to load yml at #{SchemaVersioningMongoid::Utilities.schema_file}"
        []
      end
    end

    def load_schema_from_yml(uuid)
      schema = all_schemas.find { |s| s[:uuid] == uuid }
      schema ? schema[:fields] : nil
    end

    def find_last_schema(model_name)
      all_schemas.reverse.find { |s| s[:model_name] == model_name }
    end

    def validate_path_and_class(args)
      relative_path = args.fetch(:relative_path, nil)
      abort("You must provide a relative path.") unless relative_path

      full_path = File.join(Rails.root, 'app', 'models', relative_path)
      class_name = File.basename(full_path, ".rb").camelize
      namespace_prefix = extract_namespace_prefix_from(relative_path)
    
      klass = constantize_class_name([namespace_prefix, class_name].flatten.compact)

      return [nil, nil, nil] unless klass&.included_modules&.include?(Mongoid::Document)
      
      [full_path, klass.name, klass]
    end
    
    def extract_namespace_prefix_from(relative_path)
      if relative_path.include?("/")
        relative_path.split("/")[0..-2].map(&:camelize)
      end
    end
    
    def constantize_class_name(names)
      names.join("::").constantize
    rescue
      nil
    end

    def check_schema(full_path, class_name, klass)
      uuid = klass.const_get('SCHEMA_VERSION') rescue nil
      
      return {result: false} if uuid.nil?

      current_schema = convert_type(klass)
      saved_schema = load_schema_from_yml(uuid)
      
      last_schema_record = find_last_schema(klass.name)
      last_uuid = last_schema_record ? last_schema_record[:uuid] : nil

      warnings = []
      warnings << "WARNING: UUID for #{class_name} has changed but schema has not. Please verify if UUID change was intentional." if uuid != last_uuid
      warnings << "WARNING: UUID update needed. Schema for #{class_name} has changed but UUID has not." if current_schema != saved_schema && uuid == last_uuid

      {
        result: current_schema == saved_schema,
        warnings: warnings
      }
    end

    # Add any other utility methods you have
  end
end
