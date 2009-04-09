module DataMapper

  # :include:QUICKLINKS
  #
  # = Properties
  # Properties for a model are not derived from a database structure, but
  # instead explicitly declared inside your model class definitions. These
  # properties then map (or, if using automigrate, generate) fields in your
  # repository/database.
  #
  # If you are coming to DataMapper from another ORM framework, such as
  # ActiveRecord, this may be a fundamental difference in thinking to you.
  # However, there are several advantages to defining your properties in your
  # models:
  #
  # * information about your model is centralized in one place: rather than
  #   having to dig out migrations, xml or other configuration files.
  # * use of mixins can be applied to model properties: better code reuse
  # * having information centralized in your models, encourages you and the
  #   developers on your team to take a model-centric view of development.
  # * it provides the ability to use Ruby's access control functions.
  # * and, because DataMapper only cares about properties explicitly defined
  # in
  #   your models, DataMapper plays well with legacy databases, and shares
  #   databases easily with other applications.
  #
  # == Declaring Properties
  # Inside your class, you call the property method for each property you want
  # to add. The only two required arguments are the name and type, everything
  # else is optional.
  #
  #   class Post
  #     include DataMapper::Resource
  #
  #     property :title,   String,   :nullable => false  # Cannot be null
  #     property :publish, Boolean, :default => false    # Default value for new records is false
  #   end
  #
  # By default, DataMapper supports the following primitive (Ruby) types
  # also called core types:
  #
  # * TrueClass, Boolean
  # * String (default length is 50)
  # * Text (limit of 65k characters by default)
  # * Float
  # * Integer
  # * BigDecimal
  # * DateTime
  # * Date
  # * Time
  # * Object (marshalled out during serialization)
  # * Class (datastore primitive is the same as String. Used for Inheritance)
  #
  # Other types are known as custom types.
  #
  # For more information about available Types, see DataMapper::Type
  #
  # == Limiting Access
  # Property access control is uses the same terminology Ruby does. Properties
  # are public by default, but can also be declared private or protected as
  # needed (via the :accessor option).
  #
  #  class Post
  #   include DataMapper::Resource
  #
  #    property :title,  String, :accessor => :private    # Both reader and writer are private
  #    property :body,   Text,   :accessor => :protected  # Both reader and writer are protected
  #  end
  #
  # Access control is also analogous to Ruby attribute readers and writers, and can
  # be declared using :reader and :writer, in addition to :accessor.
  #
  #  class Post
  #    include DataMapper::Resource
  #
  #    property :title, String, :writer => :private    # Only writer is private
  #    property :tags,  String, :reader => :protected  # Only reader is protected
  #  end
  #
  # == Overriding Accessors
  # The reader/writer for any property can be overridden in the same manner that Ruby
  # attr readers/writers can be.  After the property is defined, just add your custom
  # reader or writer:
  #
  #  class Post
  #    include DataMapper::Resource
  #
  #    property :title,  String
  #
  #    def title=(new_title)
  #      raise ArgumentError if new_title != 'Luke is Awesome'
  #      @title = new_title
  #    end
  #  end
  #
  # == Lazy Loading
  # By default, some properties are not loaded when an object is fetched in
  # DataMapper. These lazily loaded properties are fetched on demand when their
  # accessor is called for the first time (as it is often unnecessary to
  # instantiate -every- property -every- time an object is loaded).  For
  # instance, DataMapper::Types::Text fields are lazy loading by default,
  # although you can over-ride this behavior if you wish:
  #
  # Example:
  #
  #  class Post
  #    include DataMapper::Resource
  #
  #    property :title, String  # Loads normally
  #    property :body,  Text    # Is lazily loaded by default
  #  end
  #
  # If you want to over-ride the lazy loading on any field you can set it to a
  # context or false to disable it with the :lazy option. Contexts allow
  # multipule lazy properties to be loaded at one time. If you set :lazy to
  # true, it is placed in the :default context
  #
  #  class Post
  #    include DataMapper::Resource
  #
  #    property :title,   String                                  # Loads normally
  #    property :body,    Text,   :lazy => false                  # The default is now over-ridden
  #    property :comment, String, lazy => [ :detailed ]           # Loads in the :detailed context
  #    property :author,  String, lazy => [ :summary,:detailed ]  # Loads in :summary & :detailed context
  #  end
  #
  # Delaying the request for lazy-loaded attributes even applies to objects
  # accessed through associations. In a sense, DataMapper anticipates that
  # you will likely be iterating over objects in associations and rolls all
  # of the load commands for lazy-loaded properties into one request from
  # the database.
  #
  # Example:
  #
  #   Widget.get(1).components
  #     # loads when the post object is pulled from database, by default
  #
  #   Widget.get(1).components.first.body
  #     # loads the values for the body property on all objects in the
  #     # association, rather than just this one.
  #
  #   Widget.get(1).components.first.comment
  #     # loads both comment and author for all objects in the association
  #     # since they are both in the :detailed context
  #
  # == Keys
  # Properties can be declared as primary or natural keys on a table.
  # You should a property as the primary key of the table:
  #
  # Examples:
  #
  #  property :id,        Serial                # auto-incrementing key
  #  property :legacy_pk, String, :key => true  # 'natural' key
  #
  # This is roughly equivalent to ActiveRecord's <tt>set_primary_key</tt>,
  # though non-integer data types may be used, thus DataMapper supports natural
  # keys. When a property is declared as a natural key, accessing the object
  # using the indexer syntax <tt>Class[key]</tt> remains valid.
  #
  #   User.get(1)
  #      # when :id is the primary key on the users table
  #   User.get('bill')
  #      # when :name is the primary (natural) key on the users table
  #
  # == Indices
  # You can add indices for your properties by using the <tt>:index</tt>
  # option. If you use <tt>true</tt> as the option value, the index will be
  # automatically named. If you want to name the index yourself, use a symbol
  # as the value.
  #
  #   property :last_name,  String, :index => true
  #   property :first_name, String, :index => :name
  #
  # You can create multi-column composite indices by using the same symbol in
  # all the columns belonging to the index. The columns will appear in the
  # index in the order they are declared.
  #
  #   property :last_name,  String, :index => :name
  #   property :first_name, String, :index => :name
  #      # => index on (last_name, first_name)
  #
  # If you want to make the indices unique, use <tt>:unique_index</tt> instead
  # of <tt>:index</tt>
  #
  # == Inferred Validations
  # If you require the dm-validations plugin, auto-validations will
  # automatically be mixed-in in to your model classes:
  # validation rules that are inferred when properties are declared with
  # specific column restrictions.
  #
  #  class Post
  #    include DataMapper::Resource
  #
  #    property :title, String, :length => 250
  #      # => infers 'validates_length :title,
  #             :minimum => 0, :maximum => 250'
  #
  #    property :title, String, :nullable => false
  #      # => infers 'validates_present :title
  #
  #    property :email, String, :format => :email_address
  #      # => infers 'validates_format :email, :with => :email_address
  #
  #    property :title, String, :length => 255, :nullable => false
  #      # => infers both 'validates_length' as well as
  #      #    'validates_present'
  #      #    better: property :title, String, :length => 1..255
  #
  #  end
  #
  # This functionality is available with the dm-validations gem, part of the
  # dm-more bundle. For more information about validations, check the
  # documentation for dm-validations.
  #
  # == Default Values
  # To set a default for a property, use the <tt>:default</tt> key.  The
  # property will be set to the value associated with that key the first time
  # it is accessed, or when the resource is saved if it hasn't been set with
  # another value already.  This value can be a static value, such as 'hello'
  # but it can also be a proc that will be evaluated when the property is read
  # before its value has been set.  The property is set to the return of the
  # proc.  The proc is passed two values, the resource the property is being set
  # for and the property itself.
  #
  #   property :display_name, String, :default => { |r, p| r.login }
  #
  # Word of warning.  Don't try to read the value of the property you're setting
  # the default for in the proc.  An infinite loop will ensue.
  #
  # == Embedded Values
  # As an alternative to extraneous has_one relationships, consider using an
  # EmbeddedValue.
  #
  # == Property options reference
  #
  #  :accessor            if false, neither reader nor writer methods are
  #                       created for this property
  #
  #  :reader              if false, reader method is not created for this property
  #
  #  :writer              if false, writer method is not created for this property
  #
  #  :lazy                if true, property value is only loaded when on first read
  #                       if false, property value is always loaded
  #                       if a symbol, property value is loaded with other properties
  #                       in the same group
  #
  #  :default             default value of this property
  #
  #  :nullable            if true, property may have a nil value on save
  #
  #  :key                 name of the key associated with this property.
  #
  #  :serial              if true, field value is auto incrementing
  #
  #  :field               field in the data-store which the property corresponds to
  #
  #  :size                field size. Usually makes sense for properties of type String.
  #
  #  :length              alias for :length option
  #
  #  :format              format for autovalidation. Use with dm-validations plugin.
  #
  #  :index               if true, index is created for the property. If a Symbol, index
  #                       is named after Symbol value instead of being based on property name.
  #
  #  :auto_validation     if true, automatic validation is performed on the property
  #
  #  :validates           validation context. Use together with dm-validations.
  #
  #  :unique              if true, property column is unique. Properties of type Serial
  #                       are unique by default.
  #
  #  :precision           Indicates the number of significant digits. Usually only makes sense
  #                       for float type properties. Must be >= scale option value. Default is 10.
  #
  #  :scale               The number of significant digits to the right of the decimal point.
  #                       Only makes sense for float type properties. Must be > 0.
  #                       Default is nil for Float type and 10 for BigDecimal type.
  #
  #  All other keys you pass to +property+ method are stored and available
  #  as options[:extra_keys].
  #
  # == Misc. Notes
  # * Properties declared as strings will default to a length of 50, rather than
  #   255 (typical max varchar column size).  To overload the default, pass
  #   <tt>:length => 255</tt> or <tt>:length => 0..255</tt>.  Since DataMapper
  #   does not introspect for properties, this means that legacy database tables
  #   may need their <tt>String</tt> columns defined with a <tt>:length</tt> so
  #   that DM does not apply an un-needed length validation, or allow overflow.
  # * You may declare a Property with the data-type of <tt>Class</tt>.
  #   see SingleTableInheritance for more on how to use <tt>Class</tt> columns.
  class Property
    include Extlib::Assertions

    # NOTE: check is only for psql, so maybe the postgres adapter should
    # define its own property options. currently it will produce a warning tho
    # since PROPERTY_OPTIONS is a constant
    #
    # NOTE: PLEASE update PROPERTY_OPTIONS in DataMapper::Type when updating
    # them here
    PROPERTY_OPTIONS = [
      :accessor, :reader, :writer,
      :lazy, :default, :nullable, :key, :serial, :field, :size, :length,
      :format, :index, :auto_validation,
      :validates, :unique, :precision, :scale
    ]

    # Possible :visibility option values
    VISIBILITY_OPTIONS = [ :public, :protected, :private ].to_set.freeze

    attr_reader :model, :name, :instance_variable_name,
      :type, :reader_visibility, :writer_visibility, :options,
      :default, :precision, :scale, :repository_name

    # Supplies the field in the data-store which the property corresponds to
    #
    # @return [String] name of field in data-store
    #
    # @api semipublic
    def field(repository_name = nil)
      if repository_name
        warn "Passing in +repository_name+ to #{self.class}#field is deprecated: #{caller[0]}"

        if repository_name != self.repository_name
          raise ArgumentError, "Mismatching +repository_name+ with #{self.class}#repository_name (#{repository_name.inspect} != #{self.repository_name.inspect})"
        end
      end

      # defer setting the field with the adapter specific naming
      # conventions until after the adapter has been setup
      @field ||= model.field_naming_convention(self.repository_name).call(self).freeze
    end

    # Returns true if property is unique. Serial properties and keys
    # are unique by default.
    #
    # @return [TrueClass, FalseClass]
    #   true if property has uniq index defined, false otherwise
    #
    # @api public
    def unique?
      @unique
    end

    def unique
      warn "#{self}#unique is deprecated, use #{self}#unique?"
      unique?
    end

    ##
    # Compares another Property for equivalency
    #
    #   TODO: needs example
    #
    # @param [Property] other
    #   the other Property to compare with
    #
    # @return [TrueClass, FalseClass]
    #   true if they are equivalent, false if not
    #
    # @api semipublic
    def ==(other)
      if equal?(other)
        return true
      end

      unless other.respond_to?(:model) && other.respond_to?(:name)
        return false
      end

      cmp?(other, :==)
    end

    ##
    # Compares another Property for equality
    #
    #   TODO: needs example
    #
    # @param [Property] other
    #   the other Property to compare with
    #
    # @return [TrueClass, FalseClass]
    #   true if they are equal, false if not
    #
    # @api semipublic
    def eql?(other)
      if equal?(other)
        return true
      end

      unless other.kind_of?(self.class)
        return false
      end

      cmp?(other, :eql?)
    end

    # Returns maximum property length (if applicable).
    # This usually only makes sense when property is of
    # type Range or custom type.
    #
    # @return [Integer, NilClass]
    #   the maximum length of this property
    #
    # @api semipublic
    def length
      @length.kind_of?(Range) ? @length.max : @length
    end

    alias size length

    # Returns index name if property has index.
    #
    # @return [TrueClass,Symbol,Array,NilClass]
    #   returns true if property is indexed by itself
    #   returns a Symbol if the property is indexed with other properties
    #   returns an Array if the property belongs to multiple indexes
    #   returns nil if the property does not belong to any indexes
    #
    # @api public
    def index
      @index
    end

    # Returns whether or not the property is to be lazy-loaded
    #
    # @return [TrueClass, FalseClass]
    #   true if the property is to be lazy-loaded
    #
    # @api public
    def lazy?
      @lazy
    end

    # Returns whether or not the property is a key or a part of a key
    #
    # @return [TrueClass, FalseClass]
    #   true if the property is a key or a part of a key
    #
    # @api public
    def key?
      @key
    end

    # Returns whether or not the property is "serial" (auto-incrementing)
    #
    # @return [TrueClass, FalseClass]
    #   whether or not the property is "serial"
    #
    # @api public
    def serial?
      @serial
    end

    # Returns whether or not the property can accept 'nil' as it's value
    #
    # @return [TrueClass, FalseClass]
    #   whether or not the property can accept 'nil'
    #
    # @api public
    def nullable?
      @nullable
    end

    # Returns whether or not the property is custom (not provided by dm-core)
    #
    # @return [TrueClass, FalseClass]
    #   whether or not the property is custom
    #
    # @api public
    def custom?
      @custom
    end

    # Standardized reader method for the property
    #
    # @param [Resource] resource
    #   model instance for which this property is to be loaded
    #
    # @return [Object]
    #   the value of this property for the provided instance
    #
    # @raise [ArgumentError] "+resource+ should be a Resource, but was ...."
    #
    # @api private
    def get(resource)
      return if resource.nil?

      if resource.new?
        if loaded?(resource)
          get!(resource)
        elsif default?
          set(resource, default_for(resource))
        else
          nil
        end
      else
        lazy_load(resource) unless loaded?(resource)
        get!(resource)
      end
    end

    # Bypases resource loading and returns value of
    # @ivar on the object directly.
    #
    # Keep in mind this method is not safe and should be
    # used with care.
    #
    # @param [Resource] resource
    #   model instance for which this property is to be unsafely loaded
    #
    # @return [Object]
    #   current @ivar value of this property in +resource+
    #
    # @api private
    def get!(resource)
      resource.instance_variable_get(instance_variable_name)
    end

    # Sets original value of the property on given resource.
    # When property is set on DataMapper resource instance,
    # original value is preserved. This makes possible to
    # track dirty attributes and save only those really changed,
    # and avoid extra queries to the data source in certain
    # situations.
    #
    # @param [Resource] resource
    #   model instance for which to set the original value
    # @param [Object] original
    #   value to set as original value for this property in +resource+
    #
    # @api private
    def set_original_value(resource, original)
      original_values = resource.original_values
      original        = self.value(original)

      if original_values.key?(self)
        # stop tracking the value if it has not changed
        original_values.delete(self) if original == original_values[self] && resource.saved?
      else
        original_values[self] = original
      end
    end

    # Provides a standardized setter method for the property
    #
    # @param [Resource] resource
    #   model instance for which this property is to be set
    # @param [Object] value
    #   value to which value of this property will be set for +resource+
    #
    # @return [Object]
    #   +value+ 
    #
    # @raise [ArgumentError] "+resource+ should be a Resource, but was ...."
    #
    # @api private
    def set(resource, value)
      loaded   = loaded?(resource)
      original = get!(resource) if loaded

      if loaded && value == original
        return original
      end

      set_original_value(resource, original)

      set!(resource, value)
    end

    # Bypases resource loading and sets value on
    # @ivar of the object directly.
    #
    # Keep in mind this method is not safe and should be
    # used with care.
    #
    # @param [Resource] resource
    #   the model instance for which to unsafely set the value of this property
    # @param [Object] value
    #   the value to which this property should be unsafely set for +resource+
    #
    # @return [Object]
    #   +value+, the value to which this property was unsafely set for +resource+
    #
    # @api private
    def set!(resource, value)
      resource.instance_variable_set(instance_variable_name, value)
    end

    # Check if the attribute corresponding to the property is loaded
    #
    # @param [Resource] resource
    #   model instance for which the attribute is to be tested
    #
    # @return [TrueClass,FalseClass]
    #   true if the attribute is loaded in the resource
    #
    # @api private
    def loaded?(resource)
      resource.instance_variable_defined?(instance_variable_name)
    end

    # Loads lazy columns when get or set is called.
    #
    # @param [Resource] resource
    #   model instance for which lazy loaded attribute are loaded
    #
    # @api private
    def lazy_load(resource)
      # If we're trying to load a lazy property, load it. Otherwise, lazy-load
      # any properties that should be eager-loaded but were not included
      # in the original :fields list
      contexts = lazy? ? name : model.properties(resource.repository.name).defaults
      resource.send(:lazy_load, contexts)
    end

    # Returns a default value of the
    # property for given resource.
    #
    # When default value is a callable object,
    # it is called with resource and property passed
    # as arguments.
    #
    # @param [Resource] resource
    #   the model instance for which the default is to be set
    #
    # @return [Object]
    #   the default value of this property for +resource+
    #
    # @api semipublic
    def default_for(resource)
      @default.respond_to?(:call) ? @default.call(resource, self) : @default.try_dup
    end

    # Returns true if the property has a default value
    #
    # @return [TrueClass,FalseClass]
    #   true if the property has a default value
    #
    # @api semipublic
    def default?
      @options.key?(:default)
    end

    # Returns given value unchanged for core types and
    # uses +dump+ method of the property type for custom types.
    #
    # @param [Object] val
    #   the value to be converted into a storeable (ie., primitive) value
    #
    # @return [Object]
    #   the primitive value to be stored in the repository for +val+
    #
    # @api semipublic
    def value(value)
      custom? ? self.type.dump(value, self) : value
    end

    # Returns a concise string representation of the property instance.
    #
    # @return [String]
    #   Concise string representation of the property instance.
    #
    # @api public
    def inspect
      "#<#{self.class.name} @model=#{model.inspect} @name=#{name.inspect} @type=#{type.inspect}>"
    end

    # So we can detect the type of a property in a case statement, including class inheritance
    # Example:
    # @type = Integer
    # property === Numeric #=> true
    #
    def is_a?(klass)
      return true if klass == DataMapper::Property
      type.ancestors.include?(klass)
    end
    alias === is_a?
    alias kind_of? is_a?

    private

    def initialize(model, name, type, options = {})
      assert_kind_of 'model',   model,   Model
      assert_kind_of 'name',    name,    Symbol
      assert_kind_of 'type',    type,    Class, Module
      assert_kind_of 'options', options, Hash

      options = options.dup

      if String == type && options.key?(:size)
        warn "#{type} with :size option is deprecated, use String with :length instead"
        options[:length] = options.delete(:size)
      end

      assert_valid_options(options)

      @repository_name        = model.repository_name
      @model                  = model
      @name                   = name.to_s.sub(/\?$/, '').to_sym
      @type                   = type
      @options                = (@type.respond_to?(:default_options) ? @type.default_options.merge(options) : options.dup).freeze
      @instance_variable_name = "@#{@name}".freeze

      @field     = @options[:field].freeze
      @default   = @options[:default]

      @serial       = @options.fetch(:serial,       false)
      @key          = @options.fetch(:key,          false)
      @nullable     = @options.fetch(:nullable,     @key == false)
      @index        = @options.fetch(:index,        nil)
      @unique       = @options.fetch(:unique,       @serial || @key || false)
      @lazy         = @options.fetch(:lazy,         false) && !@key

      # assign attributes per-type
      if is_a?(String)
        @length    = @options.fetch(:length, nil)
      elsif BigDecimal == @type || Float == @type
        @precision = @options.fetch(:precision, nil)
        @scale     = @options.fetch(:scale,     nil)

        if @precision && !@precision > 0
          raise ArgumentError, "precision must be greater than 0, but was #{@precision.inspect}"
        end

        if @scale && !@scale >= 0
          raise ArgumentError, "scale must be equal to or greater than 0, but was #{@scale.inspect}"
        end

        if @precision && @precision && !@precision >= @scale
          raise ArgumentError, "precision must be equal to or greater than scale, but was #{@precision.inspect} and scale was #{@scale.inspect}"
        end
      end

      determine_visibility
      create_reader
      create_writer

    end

    def assert_valid_options(options)
      if (unknown = options.keys - PROPERTY_OPTIONS).any?
        raise ArgumentError, "options #{unknown.map { |o| o.inspect }.join(' and ')} are unknown"
      end

      options.each do |key,value|
        case key
          when :field
            assert_kind_of "options[#{key.inspect}]", value, String

          when :default
            if value.nil?
              raise ArgumentError, "options[#{key.inspect}] must not be nil"
            end

          when :serial, :key, :nullable, :unique, :lazy, :auto_validation
            unless value == true || value == false
              raise ArgumentError, "options[#{key.inspect}] must be either true or false"
            end

          when :index
            assert_kind_of "options[#{key.inspect}]", value, Symbol, Array, TrueClass

          when :length
            assert_kind_of "options[#{key.inspect}]", value, Range, Integer

          when :size, :precision, :scale
            assert_kind_of "options[#{key.inspect}]", value, Integer

          when :reader, :writer, :accessor
            assert_kind_of "options[#{key.inspect}]", value, Symbol

            unless VISIBILITY_OPTIONS.include?(value)
              raise ArgumentError, "options[#{key.inspect}] must be #{VISIBILITY_OPTIONS.join(' or ')}"
            end
        end
      end
    end

    # Assert given visibility value is supported.
    #
    # Will raise ArgumentError if this Property's reader and writer
    # visibilities are not included in VISIBILITY_OPTIONS.
    # @return [NilClass]
    # @raise [ArgumentError] "property visibility must be :public, :protected, or :private"
    # @api private
    def determine_visibility
      @reader_visibility = @options[:reader] || @options[:accessor] || :public
      @writer_visibility = @options[:writer] || @options[:accessor] || :public
    end

    # defines the reader method for the property
    #
    # @api private
    def create_reader
      unless model.instance_methods(false).any? { |m| m.to_sym == name }
        model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          #{reader_visibility}
          def #{name}
            return #{instance_variable_name} if defined?(#{instance_variable_name})
            #{instance_variable_name} = properties[#{name.inspect}].get(self)
          end
        RUBY
      end

      boolean_reader_name = "#{name}?".to_sym

      if type == TrueClass && !model.instance_methods(false).any? { |m| m.to_sym == boolean_reader_name }
        model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          #{reader_visibility}
          alias #{name}? #{name}
        RUBY
      end
    end

    # defines the setter for the property
    #
    # @api private
    def create_writer
      writer_name = "#{name}=".to_sym

      return if model.instance_methods(false).any? { |m| m.to_sym == writer_name }

      model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        #{writer_visibility}
        def #{writer_name}(value)
          properties[#{name.inspect}].set(self, value)
        end
      RUBY
    end

    ##
    # Return true if +other+'s is equivalent or equal to +self+'s
    #
    # @param [Property] other
    #   The Property whose attributes are to be compared with +self+'s
    # @param [Symbol] operator
    #   The comparison operator to use to compare the attributes
    #
    # @return [TrueClass, FalseClass]
    #   The result of the comparison of +other+'s attributes with +self+'s
    #
    # @api private
    def cmp?(other, operator)
      unless model.send(operator, other.model)
        return false
      end

      unless name.send(operator, other.name)
        return false
      end

      true
    end
  end # class Property
end # module DataMapper
