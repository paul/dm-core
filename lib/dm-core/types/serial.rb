module DataMapper
  module Types
    class Serial < Integer
      include DataMapper::Type
      default_options[:serial] = true
    end # class Text
  end # module Types
end # module DataMapper
