# frozen_string_literal: true

require 'rails'
require_relative 'schema_versioning_mongoid/version'
require_relative 'schema_versioning_mongoid/utilities'
require_relative 'schema_versioning_mongoid/rspec_helper'
require_relative 'schema_versioning_mongoid/strategies'


module SchemaVersioningMongoid
  class Error < StandardError; end
  
  class Railtie < Rails::Railtie
    rake_tasks do
      load 'tasks/all_tasks.rake'
    end
  end
end
