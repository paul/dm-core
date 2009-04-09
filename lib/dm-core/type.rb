module DataMapper

  module Type

    def self.included(klass)
      klass.extend ClassMethods
    end

    module ClassMethods

      # Gives all the default options set on this type.
      # The default options are passed into a Property as defaults for the 
      # property options.
      #
      # @return [Hash] with all options and their values set on this type
      #
      # @api public
      def default_options
        @default_options ||= {}
      end

    end # module ClassMethods

  end # module Type

end # module DataMapper
