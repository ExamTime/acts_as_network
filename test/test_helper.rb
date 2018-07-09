$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'fileutils'
require 'logger'
require 'rubygems'
require 'active_record'
require 'active_support/test_case'
require 'minitest/autorun'
require 'acts_as_network'
require 'byebug'

include FileUtils::Verbose

config = YAML::load(IO.read( File.join(File.dirname(__FILE__),'database.yml')))

# cleanup logs and databases between test runs
rm_f config['sqlite3'][:database]
rm_f File.join(File.dirname(__FILE__), 'debug.log')

ActiveRecord::Base.logger = Logger.new(File.join(File.dirname(__FILE__), "debug.log"))
ActiveRecord::Base.configurations = config
ActiveRecord::Base.establish_connection(:sqlite3)

load(File.join(File.dirname(__FILE__), "schema.rb"))

class ActiveSupport::TestCase
  include ActiveRecord::TestFixtures

  self.fixture_path = File.join(File.dirname(__FILE__), 'fixtures')
  self.pre_loaded_fixtures = true

  # Turn off transactional fixtures if you're working with MyISAM tables in MySQL
  self.use_transactional_fixtures = true

  # Instantiated fixtures are slow, but give you @david where you otherwise would need people(:david)
  self.use_instantiated_fixtures  = false

  fixtures :all
end
