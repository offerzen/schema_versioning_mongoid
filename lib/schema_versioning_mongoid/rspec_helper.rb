require_relative 'utilities'

module SchemaVersioningMongoid
  module RSpecHelper
    include SchemaVersioningMongoid::Utilities
    
    def self.check_schemas_and_uuids(reject_patterns = '')
      # Implement your logic to check schemas and UUIDs.
      # Return true if everything is up-to-date, false otherwise.
      all_up_to_date = true  # start optimistic

      reject_patterns = reject_patterns.split(',')

      model_files = Dir["#{Rails.root}/app/models/**/*.rb"]
        .reject { |item| reject_patterns.any? { |pattern| item.include?(pattern) } }

      model_files.each do |model_file|
        require model_file

        relative_path = model_file.sub("#{Rails.root}/app/models/", "")
        full_path, class_name, klass = validate_path_and_class({ relative_path: relative_path })

        next unless klass && klass.included_modules.include?(Mongoid::Document)

        # Check the schema and uuid
        schema_check_result = check_schema(full_path, class_name, klass)
        model_up_to_date = schema_check_result[:result]

        # Accumulate the results
        all_up_to_date &= model_up_to_date

        unless model_up_to_date
          puts "Schema and/or UUID for #{class_name} is not up-to-date! \n\t#{schema_check_result[:warnings]}"
        end
      end

      all_up_to_date
    end
  end
end
