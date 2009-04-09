require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

# run the specs once with a loaded association and once not
[ false, true ].each do |loaded|
  describe 'Many to Many Associations' do
    extend DataMapper::Spec::CollectionHelpers::GroupMethods

    self.loaded = loaded

    # define the model prior to supported_by
    before :all do
      class ::Author
        include DataMapper::Resource

        property :id,   Integer, :serial => true, :key => true
        property :name, String

        has n, :articles, :through => Resource
      end

      class ::Article
        include DataMapper::Resource

        property :id,      Integer, :serial => true, :key => true
        property :title,   String, :nullable => false
        property :content, String, :lazy => true

        has n, :authors, :through => Resource
        belongs_to :original, :model => self
        has n, :revisions, :model => self, :child_key => [ :original_id ]
      end

      # FIXME: make it so we don't have to "prime" the through association
      # for the join model to be created by auto_migrate
      Author.relationships[:articles].through
      Article.relationships[:authors].through

      @model = Article
    end

    supported_by :all do
      before :all do
        @author = Author.create(:name => 'Dan Kubb')

        @original = @author.articles.create(:title => 'Original Article')
        @article  = @author.articles.create(:title => 'Sample Article', :content => 'Sample', :original => @original)
        @other    = @author.articles.create(:title => 'Other Article',  :content => 'Other')

        @articles       = @author.articles(:title => 'Sample Article')
        @other_articles = @author.articles(:title => 'Other Article')
      end

      it_should_behave_like 'A public Collection'
    end
  end
end
