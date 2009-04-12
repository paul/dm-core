require 'pathname'
require 'rubygems'

gem 'rspec', '~>1.2'
require 'spec'

SPEC_ROOT = Pathname(__FILE__).dirname.expand_path
$LOAD_PATH.unshift(SPEC_ROOT.parent + 'lib')

require 'dm-core'
require 'dm-core/core_ext/symbol'

Pathname.glob((SPEC_ROOT + '{lib,*/shared}/**/*.rb').to_s).each { |f| require f }

DataMapper::Logger.new(nil, :debug)

Spec::Runner.configure do |config|
  config.include(DataMapper::Spec::PendingHelpers)

  config.before :all do
    @adapter = ::DataMapper.setup(:default, :adapter => :in_memory)
    @repository = ::DataMapper.repository(:default)

    @alternate_adapter = ::DataMapper.setup(:alternate, :adapter => :in_memory)
    @alternate_repository = ::DataMapper.repository(:alternate)
  end

  config.after :all do
    # global model cleanup
    descendants = DataMapper::Model.descendants.dup.to_a
    while model = descendants.shift
      descendants.concat(model.descendants) if model.respond_to?(:descendants)
      Object.send(:remove_const, model.name.to_sym)
      DataMapper::Model.descendants.delete(model)
    end
  end
end
