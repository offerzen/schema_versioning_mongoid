module SchemaVersioningMongoid
  module Strategies
    class Inline
      def self.update(full_path, _class_name, uuid, content)
        new_content = update_existing_schema_version(content, uuid)
        File.write(full_path, new_content)
      end

      def self.insert(full_path, _class_name, uuid, content)
        new_content = insert_new_schema_version(content, uuid)
        File.write(full_path, new_content)
      end

      private

      def self.update_existing_schema_version(content, uuid)
        content.gsub(/(SCHEMA_VERSION\s*=\s*)'[^']*'/, "SCHEMA_VERSION = '#{uuid}'")
      end

      def self.insert_new_schema_version(content, uuid)
        pattern = /include Mongoid::Document/
        if content.scan(pattern).empty?
          class_definition_pattern = /(class\s+[A-Za-z0-9_:]+(\s*<\s*[A-Za-z0-9_:]+)?)(\n|\s+)/
          replacement = "\\1\n  SCHEMA_VERSION = '#{uuid}'\\3"
          content.gsub(class_definition_pattern, replacement)
        else
          replacement = "include Mongoid::Document; SCHEMA_VERSION = '#{uuid}'"
          content.gsub(pattern, replacement)
        end
      end
    end

    class Centralized
      @@centralized_schema_versions = {}
    
      def self.update(_full_path, class_name, uuid, _content)
        update_centralized_schema_version(class_name, uuid)
      end
    
      def self.insert(_full_path, class_name, uuid, _content)
        update_centralized_schema_version(class_name, uuid)
      end
    
      def self.update_centralized_schema_version(klass_name, new_uuid)
        file_path = "db/schema_versions_centralized.yml"
    
        if File.exist?(file_path)
          centralized_schema_versions = YAML.load_file(file_path) || {}
        else
          centralized_schema_versions = {}
        end
    
        centralized_schema_versions[klass_name] = new_uuid
    
        File.open(file_path, 'w') do |f|
          f.write(centralized_schema_versions.to_yaml)
        end
      end
    end
  end
end
