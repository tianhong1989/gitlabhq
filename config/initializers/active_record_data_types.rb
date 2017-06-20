# ActiveRecord custom data type for storing datetimes with timezone information.
# See https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/11229

if Gitlab::Database.postgresql?
  require 'active_record/connection_adapters/postgresql_adapter'

  module ActiveRecord::ConnectionAdapters::PostgreSQL::OID
    # Add the class `DateTimeWithTimeZone` so we can map `timestamptz` to it.
    class DateTimeWithTimeZone < DateTime
      def type
        :datetime_with_timezone
      end
    end
  end

  module RegisterDateTimeWithTimeZone
    # Run original `initialize_type_map` and then register `timestamptz` as a
    # `DateTimeWithTimeZone`.
    #
    # Apparently it does not matter that the original `initialize_type_map`
    # aliases `timestamptz` to `timestamp`.
    #
    # When schema dumping, `timestamptz` columns will be output as
    # `t.datetime_with_timezone`.
    def initialize_type_map(mapping)
      super mapping

      mapping.register_type 'timestamptz' do |_, _, sql_type|
        precision = extract_precision(sql_type)
        ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::OID::DateTimeWithTimeZone.new(precision: precision)
      end
    end
  end

  class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
    prepend RegisterDateTimeWithTimeZone

    # Add column type `datetime_with_timezone` so we can do this in
    # migrations:
    #
    #   add_column(:users, :datetime_with_timezone)
    #
    NATIVE_DATABASE_TYPES[:datetime_with_timezone] = { name: 'timestamptz' }
  end
elsif Gitlab::Database.mysql?
  require 'active_record/connection_adapters/mysql2_adapter'

  module ActiveRecord
    module ConnectionAdapters
      class AbstractMysqlAdapter
        NATIVE_DATABASE_TYPES[:datetime_with_timezone] = { name: 'timestamp' }
      end
    end
  end
end
