module DataMapper
  # Set of Property objects, used to associate
  # queries with set of fields it performed over,
  # to represent composite keys (esp. for associations)
  # and so on.
  class PropertySet < Array
    def [](name)
      @properties[name]
    end

    def []=(name, property)
      if named?(name)
        add_property(property)
        map! { |p| p == property || p.name == property.name ? property : p }
      else
        self << property
      end
    end

    def named?(name)
      @properties.key?(name)
    end

    def has_property?(name)
      warn "#{self.class}#has_property? is deprecated, use #{self.class}#named? instead"
      named?(name)
    end

    def values_at(*names)
      @properties.values_at(*names)
    end

    def slice(*args)
      warn "#{self.class}#slice is deprecated, use #{self.class}#values_at instead"
      values_at(*args)
    end

    def <<(property)
      add_property(property)
      super
    end

    def add(*args)
      warn "#{self.class}#add is deprecated, use #{self.class}#<< instead"
      self.<<(*args)
    end

    def include?(property)
      named?(property.name)
    end

    # TODO: make PropertySet#reject return a PropertySet instance
    def defaults
      @defaults ||= key | reject { |p| p.lazy? }.freeze
    end

    def key
      @key ||= select { |p| p.key? }.freeze
    end

    def indexes
      index_hash = {}
      each { |p| parse_index(p.index, p.field, index_hash) }
      index_hash
    end

    def unique_indexes
      index_hash = {}
      each { |p| parse_index(p.unique_index, p.field, index_hash) }
      index_hash
    end

    def get(resource)
      map { |p| p.get(resource) }
    end

    def set(resource, values)
      zip(values) { |p,v| p.set(resource, v) }
    end

    def property_contexts(name)
      contexts = []
      lazy_contexts.each do |context,property_names|
        contexts << context if property_names.include?(name)
      end
      contexts
    end

    def lazy_context(name)
      lazy_contexts[name] ||= []
    end

    def lazy_load_context(names)
      if names.kind_of?(Array) && names.empty?
        raise ArgumentError, '+names+ cannot be empty'
      end

      result = []

      Array(names).each do |name|
        contexts = property_contexts(name)
        if contexts.empty?
          result << name  # not lazy
        else
          result |= lazy_contexts.values_at(*contexts).flatten.uniq
        end
      end
      result
    end

    def inspect
      "#<#{self.class.name} { #{ map { |p| p.inspect }.join(', ') } }>"
    end

    private

    def initialize(*)
      super
      @properties = map { |p| [ p.name, p ] }.to_mash
    end

    def initialize_copy(*)
      super
      @properties = @properties.dup
    end

    def add_property(property)
      clear_cache
      @properties[property.name] = property
    end

    def clear_cache
      @defaults, @key, @discriminator = nil
    end

    def lazy_contexts
      @lazy_contexts ||= {}
    end

    def parse_index(index, property, index_hash)
      case index
        when true
          index_hash[property] = [ property ]
        when Symbol
          index_hash[index] ||= []
          index_hash[index] << property
        when Array
          index.each { |idx| parse_index(idx, property, index_hash) }
      end
    end
  end # class PropertySet
end # module DataMapper
