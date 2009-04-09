require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe "DataMapper custom types" do

  describe 'setting default options on the property' do
    before do
      class DefaultUniqueType < String
        include DataMapper::Type

        default_options[:unique] = true
      end

      class ModelWithCustomType
        include DataMapper::Resource

        property :name, DefaultUniqueType
      end
    end

    it 'should set the default option on the custom type' do
      default_options = DefaultUniqueType.default_options

      default_options.should have_key(:unique)
      default_options[:unique].should be_true
    end

    it 'should set the default option on the property' do
      options = ModelWithCustomType.properties[:name].options

      options.should have_key(:unique)
      options[:unique].should be_true
    end

  end

end

