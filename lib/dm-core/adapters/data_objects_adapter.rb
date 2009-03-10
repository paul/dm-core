gem 'data_objects', '~>0.9.12'
require 'data_objects'

module DataMapper
  module Adapters
    # You must inherit from the DoAdapter, and implement the
    # required methods to adapt a database library for use with the DataMapper.
    #
    # NOTE: By inheriting from DataObjectsAdapter, you get a copy of all the
    # standard sub-modules (Quoting, Coersion and Queries) in your own Adapter.
    # You can extend and overwrite these copies without affecting the originals.
    class DataObjectsAdapter < AbstractAdapter
      extend Chainable

      ##
      # For each model instance in resources, issues an SQL INSERT
      # (or equivalent) statement to create a new record in the data store for
      # the instance
      #
      # @param [Array] resources
      #   The set of resources (model instances)
      #
      # @return [Integer]
      #   The number of records that were actually saved into the data-store
      #
      # @api semipublic
      def create(resources)
        created = 0
        resources.each do |resource|
          model          = resource.model
          identity_field = model.identity_field
          attributes     = resource.dirty_attributes

          properties  = []
          bind_values = []

          # make the order of the properties consistent
          model.properties(name).each do |property|
            next unless attributes.key?(property)

            bind_value = attributes[property]

            next if property.eql?(identity_field) && bind_value.nil?

            properties  << property
            bind_values << bind_value
          end

          statement = insert_statement(model, properties, identity_field)
          result    = execute(statement, *bind_values)

          if result.to_i == 1
            if identity_field
              identity_field.set!(resource, result.insert_id)
            end
            created += 1
          end
        end
        created
      end

      def read(query)
        with_connection do |connection|
          statement, bind_values = select_statement(query)

          command = connection.create_command(statement)
          command.set_types(query.fields.map { |p| p.primitive })

          begin
            reader = command.execute_reader(*bind_values)

            model     = query.model
            resources = []

            while(reader.next!)
              resources << model.load(reader.values, query)
            end

            resources
          ensure
            reader.close if reader
          end
        end
      end

      def update(attributes, query)
        # TODO: if the query contains any links, a limit or an offset
        # use a subselect to get the rows to be updated

        properties  = []
        bind_values = []

        # make the order of the properties consistent
        query.model.properties(name).each do |property|
          next unless attributes.key?(property)
          properties  << property
          bind_values << attributes[property]
        end

        statement, conditions_bind_values = update_statement(properties, query)

        bind_values.concat(conditions_bind_values)

        execute(statement, *bind_values).to_i
      end

      def delete(query)
        # TODO: if the query contains any links, a limit or an offset
        # use a subselect to get the rows to be deleted

        statement, bind_values = delete_statement(query)
        execute(statement, *bind_values).to_i
      end

      # Database-specific method
      def execute(statement, *bind_values)
        with_connection do |connection|
          command = connection.create_command(statement)
          command.execute_non_query(*bind_values)
        end
      end

      def query(statement, *bind_values)
        with_connection do |connection|
          begin
            reader = connection.create_command(statement).execute_reader(*bind_values)

            results = []

            if (fields = reader.fields).size > 1
              fields = fields.map { |f| Extlib::Inflection.underscore(f).to_sym }
              struct = Struct.new(*fields)

              while(reader.next!) do
                results << struct.new(*reader.values)
              end
            else
              while(reader.next!) do
                results << reader.values.at(0)
              end
            end

            results
          ensure
            reader.close if reader
          end
        end
      end

      protected

      def normalized_uri
        @normalized_uri ||=
          begin
            query = @options.except(:adapter, :user, :password, :host, :port, :path, :fragment)
            query = nil if query.empty?

            DataObjects::URI.new(
              @options[:adapter],
              @options[:user],
              @options[:password],
              @options[:host],
              @options[:port],
              @options[:path],
              query,
              @options[:fragment]
            ).freeze
          end
      end

      chainable do
        protected

        # @api semipublic
        def create_connection
          # DataObjects::Connection.new(uri) will give you back the right
          # driver based on the DataObjects::URI#scheme
          DataObjects::Connection.new(normalized_uri)
        end

        # @api semipublic
        def close_connection(connection)
          connection.close
        end
      end

      private

      def initialize(name, uri_or_options)
        super

        # Default the driver-specific logger to DataMapper's logger
        if driver_module = DataObjects.const_get(normalized_uri.scheme.capitalize)
          driver_module.logger = DataMapper.logger if driver_module.respond_to?(:logger=)
        end
      end

      def with_connection
        begin
          connection = create_connection
          return yield(connection)
        rescue => e
          DataMapper.logger.error(e.to_s)
          raise e
        ensure
          close_connection(connection) if connection
        end
      end

      # This module is just for organization. The methods are included into the
      # Adapter below.
      module SQL #:nodoc:

        # TODO: document this
        # @api semipublic
        def property_to_column_name(property, qualify)
          if qualify
            table_name = property.model.storage_name(name)
            "#{quote_name(table_name)}.#{quote_name(property.field)}"
          else
            quote_name(property.field)
          end
        end

        private

        # Adapters requiring a RETURNING syntax for INSERT statements
        # should overwrite this to return true.
        def supports_returning?
          false
        end

        # Adapters that do not support the DEFAULT VALUES syntax for
        # INSERT statements should overwrite this to return false.
        def supports_default_values?
          true
        end

        def select_statement(query)
          model      = query.model
          fields     = query.fields
          conditions = query.conditions
          limit      = query.limit
          offset     = query.offset
          order      = query.order
          group_by   = nil

          qualify = query.links.any?

          if qualify || query.unique?
            group_by = fields.select { |p| p.kind_of?(Property) }
          end

          unless (limit && limit > 1) || offset > 0 || qualify
            if conditions.any? { |o,p,b| o == :eql && p.unique? && !b.kind_of?(Array) && !b.kind_of?(Range) }
              order = nil
              limit = nil
            end
          end

          where_statement, bind_values = where_statement(conditions, qualify)

          statement = "SELECT #{columns_statement(fields, qualify)}"
          statement << " FROM #{quote_name(model.storage_name(name))}"
          statement << join_statement(model, query.links, qualify)         if qualify
          statement << " WHERE #{where_statement}"                         unless where_statement.blank?
          statement << " GROUP BY #{columns_statement(group_by, qualify)}" if group_by && group_by.any?
          statement << " ORDER BY #{order_statement(order, qualify)}"      if order && order.any?
          statement << " LIMIT #{quote_value(limit)}"                      if limit
          statement << " OFFSET #{quote_value(offset)}"                    if limit && offset > 0

          return statement, bind_values || []
        end

        def insert_statement(model, properties, identity_field)
          statement = "INSERT INTO #{quote_name(model.storage_name(name))} "

          if supports_default_values? && properties.empty?
            statement << 'DEFAULT VALUES'
          else
            statement << <<-SQL.compress_lines
              (#{properties.map { |p| quote_name(p.field) }.join(', ')})
              VALUES
              (#{(['?'] * properties.size).join(', ')})
            SQL
          end

          if supports_returning? && identity_field
            statement << " RETURNING #{quote_name(identity_field.field)}"
          end

          statement
        end

        def update_statement(properties, query)
          where_statement, bind_values = where_statement(query.conditions)

          statement = "UPDATE #{quote_name(query.model.storage_name(name))}"
          statement << " SET #{properties.map { |p| "#{quote_name(p.field)} = ?" }.join(', ')}"
          statement << " WHERE #{where_statement}" unless where_statement.blank?

          return statement, bind_values
        end

        def delete_statement(query)
          where_statement, bind_values = where_statement(query.conditions)

          statement = "DELETE FROM #{quote_name(query.model.storage_name(name))}"
          statement << " WHERE #{where_statement}" unless where_statement.blank?

          return statement, bind_values
        end

        def columns_statement(properties, qualify)
          properties.map { |p| property_to_column_name(p, qualify) }.join(', ')
        end

        def join_statement(previous_model, links, qualify)
          statement = ''

          links.reverse_each do |relationship|
            model = previous_model == relationship.child_model ? relationship.parent_model : relationship.child_model

            # We only do INNER JOIN for now
            statement << " INNER JOIN #{quote_name(model.storage_name(name))} ON "

            statement << relationship.parent_key.zip(relationship.child_key).map do |parent_property,child_property|
              condition_statement(:eql, parent_property, child_property, qualify)
            end.join(' AND ')

            previous_model = model
          end

          statement
        end

        def where_statement(conditions, qualify = false)
          statements  = []
          bind_values = []

          conditions.each do |tuple|
            operator, property, bind_value = *tuple

            # handle exclusive range conditions
            if bind_value.kind_of?(Range) && bind_value.exclude_end?

              # TODO: think about updating Query so that exclusive Range conditions are
              # transformed into AND or OR conditions like below.  Effectively the logic
              # here would be moved into Query

              min = bind_value.first
              max = bind_value.last

              case operator
                when :eql
                  gte_condition = condition_statement(:gte, property, min, qualify)
                  lt_condition  = condition_statement(:lt,  property, max,  qualify)

                  statements << "#{gte_condition} AND #{lt_condition}"
                when :not
                  lt_condition  = condition_statement(:lt,  property, min, qualify)
                  gte_condition = condition_statement(:gte, property, max,  qualify)

                  if conditions.size > 1
                    statements << "(#{lt_condition} OR #{gte_condition})"
                  else
                    statements << "#{lt_condition} OR #{gte_condition}"
                  end
              end

              bind_values << min
              bind_values << max
            else
              statements << condition_statement(operator, property, bind_value, qualify)

              if operator == :raw
                bind_values.push(*bind_value) if tuple.size == 3
              else
                bind_values << bind_value
              end
            end
          end

          return statements.join(' AND '), bind_values
        end

        def order_statement(order, qualify)
          statements = order.map do |order|
            statement = property_to_column_name(order.property, qualify)
            statement << ' DESC' if order.direction == :desc
            statement
          end

          statements.join(', ')
        end

        def condition_statement(operator, left_condition, right_condition, qualify)
          return left_condition if operator == :raw

          conditions = [ left_condition, right_condition ].map do |condition|
            case condition
              when Property, Query::Path
                property_to_column_name(condition, qualify)
              else
                '?'
            end
          end

          comparison = case operator
            when :eql, :in then equality_operator(right_condition)
            when :not      then inequality_operator(right_condition)
            when :like     then like_operator(right_condition)
            when :gt       then '>'
            when :gte      then '>='
            when :lt       then '<'
            when :lte      then '<='
          end

          conditions.join(" #{comparison} ")
        end

        def equality_operator(operand)
          case operand
            when Array then 'IN'
            when Range then 'BETWEEN'
            when nil   then 'IS'
            else            '='
          end
        end

        def inequality_operator(operand)
          case operand
            when Array then 'NOT IN'
            when Range then 'NOT BETWEEN'
            when nil   then 'IS NOT'
            else            '<>'
          end
        end

        def like_operator(operand)
          operand.kind_of?(Regexp) ? '~' : 'LIKE'
        end

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        def quote_name(name)
          "\"#{name.gsub('"', '""')}\""
        end

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        def quote_value(value)
          case value
            when String
              "'#{value.gsub("'", "''")}'"
            when Integer, Float
              value.to_s
            when DateTime
              quote_value(value.strftime('%Y-%m-%d %H:%M:%S'))
            when Date
              quote_value(value.strftime('%Y-%m-%d'))
            when Time
              usec = value.usec
              quote_value(value.strftime('%Y-%m-%d %H:%M:%S') + ((usec > 0 ? ".#{usec.to_s.rjust(6, '0')}" : '')))
            when BigDecimal
              value.to_s('F')
            when nil
              'NULL'
            else
              value.to_s
          end
        end
      end #module SQL

      include SQL
    end # class DataObjectsAdapter

    const_added(:DataObjectsAdapter)
  end # module Adapters

  # TODO: move to dm-ar-finders
  module Model
    #
    # Find instances by manually providing SQL
    #
    # @param sql<String>   an SQL query to execute
    # @param <Array>    an Array containing a String (being the SQL query to
    #   execute) and the parameters to the query.
    #   example: ["SELECT name FROM users WHERE id = ?", id]
    # @param query<Query>  a prepared Query to execute.
    # @param opts<Hash>     an options hash.
    #     :repository<Symbol> the name of the repository to execute the query
    #       in. Defaults to self.default_repository_name.
    #     :reload<Boolean>   whether to reload any instances found that already
    #      exist in the identity map. Defaults to false.
    #     :properties<Array>  the Properties of the instance that the query
    #       loads. Must contain Property objects.
    #       Defaults to self.properties.
    #
    # @return <Collection> the instance matched by the query.
    #
    # @example
    #   MyClass.find_by_sql(["SELECT id FROM my_classes WHERE county = ?",
    #     selected_county], :properties => MyClass.property[:id],
    #     :repository => :county_repo)
    #
    # @api public
    def find_by_sql(*args)
      sql = nil
      query = nil
      bind_values = []
      properties = nil
      do_reload = false
      repository_name = default_repository_name
      args.each do |arg|
        if arg.kind_of?(String)
          sql = arg
        elsif arg.kind_of?(Array)
          sql = arg.first
          bind_values = arg[1..-1]
        elsif arg.kind_of?(Query)
          query = arg
        elsif arg.kind_of?(Hash)
          repository_name = arg.delete(:repository) if arg.include?(:repository)
          properties = Array(arg.delete(:properties)) if arg.include?(:properties)
          do_reload = arg.delete(:reload) if arg.include?(:reload)
          raise "unknown options to #find_by_sql: #{arg.inspect}" unless arg.empty?
        end
      end

      repository = repository(repository_name)
      raise "#find_by_sql only available for Repositories served by a DataObjectsAdapter" unless repository.adapter.kind_of?(Adapters::DataObjectsAdapter)

      if query
        sql = repository.adapter.send(:select_statement, query)
        bind_values = query.bind_values
      end

      raise "#find_by_sql requires a query of some kind to work" unless sql

      properties ||= self.properties(repository.name)

      Collection.new(Query.new(repository, self)) do |collection|
        repository.adapter.send(:with_connection) do |connection|
          command = connection.create_command(sql)

          begin
            reader = command.execute_reader(*bind_values)

            while(reader.next!)
              collection.load(reader.values)
            end
          ensure
            reader.close if reader
          end
        end
      end
    end
  end # module Model
end # module DataMapper
