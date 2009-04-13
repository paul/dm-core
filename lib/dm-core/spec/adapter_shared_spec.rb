
share_examples_for "An Adapter" do

  def self.adapter_supports?(*methods)
    methods.all? do |method|
      # TODO: figure out a way to see if the instance method is only inherited
      # from the Abstract Adapter, and not defined in it's class.  If that is
      # the case return false

      # CRUD methods can be inherited from parent class
      described_type.instance_methods.any? { |m| method.to_s == m.to_s } || (
        !described_type.parent == DataMapper::Adapters::AbstractAdapter &&
        described_type.parent.instance_methods.any? { |m| method.to_s == m.to_s }
      )
    end
  end

  before :all do
    raise "+@adapter+ should be defined in before block" unless instance_variable_get("@adapter")

    @adapter_class = @adapter.class
    @scheme        = Extlib::Inflection.underscore(Extlib::Inflection.demodulize(@adapter_class).chomp('adapter'))
    @adapter_name  = "test_#{@scheme}".to_sym
    @repository    = DataMapper.repository(@adapter.name)

    class ::Heffalump
      include DataMapper::Resource

      property :id,        Serial
      property :color,     String
      property :num_spots, Integer
      property :striped,   Boolean
    end

    # create all tables and constraints before each spec
    if @repository.respond_to?(:auto_migrate!)
      Heffalump.auto_migrate!
    end
  end

  if adapter_supports?(:create)
    describe '#create' do
      it 'should not raise any errors' do
        lambda {
          Heffalump.create(:color => 'peach')
        }.should_not raise_error
      end

      it 'should set the identity field for the resource' do
        h = Heffalump.new(:color => 'peach')
        h.id.should be_nil
        h.save
        h.id.should_not be_nil
      end
    end
  else
    it 'needs to support #create'
  end

  if adapter_supports?(:read)
    describe '#read' do
      before :all do
        @heffalump = Heffalump.create(:color => 'brownish hue')
        #just going to borrow this, so I can check the return values
        @query = Heffalump.all.query
      end

      it 'should not raise any errors' do
        lambda {
          Heffalump.all()
        }.should_not raise_error
      end

      it 'should return stuff' do
        Heffalump.all.should include(@heffalump)
      end
    end
  else
    it 'needs to support #read'
  end

  if adapter_supports?(:update)
    describe '#update' do
      before do
        @heffalump = Heffalump.create(:color => 'indigo')
      end

      it 'should not raise any errors' do
        lambda {
          @heffalump.color = 'violet'
          @heffalump.save
        }.should_not raise_error
      end

      it 'should not alter the identity field' do
        id = @heffalump.id
        @heffalump.color = 'violet'
        @heffalump.save
        @heffalump.id.should == id
      end

      it 'should not alter other fields' do
        color = @heffalump.color
        @heffalump.num_spots = 3
        @heffalump.save
        @heffalump.color.should == color
      end
    end
  else
    it 'needs to support #update'
  end

  if adapter_supports?(:delete)
    describe '#delete' do
      before do
        @heffalump = Heffalump.create(:color => 'forest green')
      end

      it 'should not raise any errors' do
        lambda {
          @heffalump.destroy
        }.should_not raise_error
      end

      it 'should delete the requested resource' do
        id = @heffalump.id
        @heffalump.destroy
        Heffalump.get(id).should be_nil
      end
    end
  else
    it 'needs to support #delete'
  end

  if adapter_supports?(:read, :create)
    describe "query matching" do
      require 'dm-core/core_ext/symbol'

      before :all do
        @red = Heffalump.create(:color => 'red')
        @two = Heffalump.create(:num_spots => 2)
        @five = Heffalump.create(:num_spots => 5)
      end

      describe 'conditions' do
        describe 'eql' do
          it 'should be able to search for objects included in an inclusive range of values' do
            Heffalump.all(:num_spots => 1..5).should include(@five)
          end

          it 'should be able to search for objects included in an exclusive range of values' do
            Heffalump.all(:num_spots => 1...6).should include(@five)
          end

          it 'should not be able to search for values not included in an inclusive range of values' do
            Heffalump.all(:num_spots => 1..4).should_not include(@five)
          end

          it 'should not be able to search for values not included in an exclusive range of values' do
            Heffalump.all(:num_spots => 1...5).should_not include(@five)
          end
        end

        describe 'not' do
          it 'should be able to search for objects with not equal value' do
            Heffalump.all(:color.not => 'red').should_not include(@red)
          end

          it 'should include objects that are not like the value' do
            Heffalump.all(:color.not => 'black').should include(@red)
          end

          it 'should be able to search for objects with not nil value' do
            Heffalump.all(:color.not => nil).should include(@red)
          end

          it 'should not include objects with a nil value' do
            Heffalump.all(:color.not => nil).should_not include(@two)
          end

          it 'should be able to search for objects not included in an array of values' do
            Heffalump.all(:num_spots.not => [ 1, 3, 5, 7 ]).should include(@two)
          end

          it 'should be able to search for objects not included in an array of values' do
            Heffalump.all(:num_spots.not => [ 1, 3, 5, 7 ]).should_not include(@five)
          end

          it 'should be able to search for objects not included in an inclusive range of values' do
            Heffalump.all(:num_spots.not => 1..4).should include(@five)
          end

          it 'should be able to search for objects not included in an exclusive range of values' do
            Heffalump.all(:num_spots.not => 1...5).should include(@five)
          end

          it 'should not be able to search for values not included in an inclusive range of values' do
            Heffalump.all(:num_spots.not => 1..5).should_not include(@five)
          end

          it 'should not be able to search for values not included in an exclusive range of values' do
            Heffalump.all(:num_spots.not => 1...6).should_not include(@five)
          end
        end

        describe 'like' do
          it 'should be able to search for objects that match value' do
            Heffalump.all(:color.like => '%ed').should include(@red)
          end

          it 'should not search for objects that do not match the value' do
            Heffalump.all(:color.like => '%blak%').should_not include(@red)
          end
        end

        describe 'regexp' do
          before do
            if defined?(DataMapper::Adapters::Sqlite3Adapter) && @adapter.kind_of?(DataMapper::Adapters::Sqlite3Adapter)
              pending 'delegate regexp matches to same system that the InMemory adapter uses'
            end
          end

          it 'should be able to search for objects that match value' do
            Heffalump.all(:color => /ed/).should include(@red)
          end

          it 'should not search for objects that do not match the value' do
            Heffalump.all(:color => /blak/).should_not include(@red)
          end
        end

        describe 'gt' do
          it 'should be able to search for objects with value greater than' do
            Heffalump.all(:num_spots.gt => 1).should include(@two)
          end

          it 'should not find objects with a value less than' do
            Heffalump.all(:num_spots.gt => 3).should_not include(@two)
          end
        end

        describe 'gte' do
          it 'should be able to search for objects with value greater than' do
            Heffalump.all(:num_spots.gte => 1).should include(@two)
          end

          it 'should be able to search for objects with values equal to' do
            Heffalump.all(:num_spots.gte => 2).should include(@two)
          end

          it 'should not find objects with a value less than' do
            Heffalump.all(:num_spots.gte => 3).should_not include(@two)
          end
        end

        describe 'lt' do
          it 'should be able to search for objects with value less than' do
            Heffalump.all(:num_spots.lt => 3).should include(@two)
          end

          it 'should not find objects with a value less than' do
            Heffalump.all(:num_spots.gt => 2).should_not include(@two)
          end
        end

        describe 'lte' do
          it 'should be able to search for objects with value less than' do
            Heffalump.all(:num_spots.lte => 3).should include(@two)
          end

          it 'should be able to search for objects with values equal to' do
            Heffalump.all(:num_spots.lte => 2).should include(@two)
          end

          it 'should not find objects with a value less than' do
            Heffalump.all(:num_spots.lte => 1).should_not include(@two)
          end
        end
      end

      describe 'limits' do
        it 'should be able to limit the objects' do
          Heffalump.all(:limit => 2).length.should == 2
        end
      end
    end
  else
    it 'needs to support #read and #create to test query matching'
  end
end
