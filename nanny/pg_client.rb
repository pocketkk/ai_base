# pg_client.rb
require 'pg'

module Nanny
  class PGClient
    def initialize(host, dbname, user, password)
      @connection = PG::Connection.open(:host => host, :dbname => dbname, :user => user, :password => password)
    end

    def save_message(message:, source:)
      res = @connection.exec_params(
        'INSERT INTO messages (content, source, created_at) VALUES ($1, $2, NOW()) RETURNING id',
        [message, source]
      )

      res[0]['id']
    end

    def table_exists?(table_name)
      res = @connection.exec_params(
        "SELECT EXISTS (
         SELECT FROM pg_tables
         WHERE  schemaname = 'public'
         AND    tablename  = $1
       )",
       [table_name]
      )
      res[0]['exists'] == 't'
    end

    def drop_table(table_name)
      return unless table_exists?(table_name)

      query = "DROP TABLE #{table_name};"
      @connection.exec(query)
    end

    def create_table(table_name, options_hash)
      fields = options_hash.map do |field, type|
        type = case type.to_sym
               when :string then 'text'
               when :integer then 'integer'
               when :float then 'float'
               when :datetime then 'timestamp'
               when :boolean then 'boolean'
               else
                 type
               end
        "#{field} #{type}"
      end.join(', ')

      query = "CREATE TABLE IF NOT EXISTS #{table_name} (#{fields});"
      @connection.exec(query)
    end

    def retrieve_message_by_id(id)
      res = @connection.exec_params(
        "SELECT * FROM messages WHERE id = $1;",
        [id]
      )

      res[0]
    end

    def messages_by_ids(ids)
      placeholders = Array(ids).map.with_index { |_, i| "$#{i+1}" }.join(",")

      res = @connection.exec_params(
        "SELECT * FROM messages WHERE id IN (#{placeholders});",
        Array(ids)
      )

      res.to_a
    end

    def retrieve_messages_since(time)
      res = @connection.exec_params(
        "SELECT * FROM messages WHERE created_at >= $1 ORDER BY created_at DESC;",
        [time]
      )

      res.to_a
    end

    def query(query, params=[])
      res = @connection.exec_params(query, params)
      res.to_a
    end
  end
end
