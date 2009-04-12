require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))
require 'dm-core/spec/adapter_shared_spec'
require 'dm-core/adapters/in_memory_adapter'

describe DataMapper::Adapters::InMemoryAdapter do

  it_should_behave_like 'An Adapter'

end
