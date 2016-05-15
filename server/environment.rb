ENV['RACK_ENV'] ||= 'development'

require 'rubygems'
require 'bundler/setup'

Bundler.require(:default, ENV['RACK_ENV'])

%w(yaml json logger).each { |lib| require lib }

LOGGER = Logger.new('log/app.log')

DB_CONFIG = YAML.load_file('db/database.yml')
DB = Sequel.connect(DB_CONFIG, logger: LOGGER)
DB.loggers << Logger.new(STDOUT) if ENV['RACK_ENV'] == 'development'

paths_to_load = %w(
  models/*.rb
)

paths_to_load.each do |path|
  location = File.expand_path(path, __dir__)
  Dir[location].each { |f| require f }
end


class Hash
  def slice(*keys)
    keys.inject({}) { |h, key| h.merge! key => self[key] }
  end
end
