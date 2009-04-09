require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Resource do
  before :all do
    class ::User
      include DataMapper::Resource

      property :name,        String, :key => true
      property :age,         Integer
      property :description, String, :lazy => true
      property :admin,       Boolean, :accessor => :private

      belongs_to :referrer, :model => self
      has n, :comments
    end

    class ::Author < User; end

    class ::Comment
      include DataMapper::Resource

      property :id,   Integer, :serial => true, :key => true
      property :body, String

      belongs_to :user
    end

    class ::Article
      include DataMapper::Resource

      property :id,   Integer, :serial => true, :key => true
      property :body, String

      has n, :paragraphs
    end

    class ::Paragraph
      include DataMapper::Resource

      property :id,   Integer, :serial => true, :key => true
      property :text, String

      belongs_to :article
    end

    @model       = User
    @child_model = Comment
  end

  supported_by :all do
    before :all do
      user = @model.create(:name => 'dbussink', :age => 25, :description => 'Test')

      @user = @model.get(*user.key)
    end

    it_should_behave_like 'A public Resource'
  end
end
