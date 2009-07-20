require "rubygems"
require "active_record"
# require "active_record/version"
module Unionizer
  
  def acts_as_unionized
    if ::ActiveRecord::VERSION::MAJOR < 2 || ::ActiveRecord::VERSION::MINOR < 1
      raise "Not supported for versions before 2.1.0"
    end
    extend ClassMethods
    metaclass::VALID_FIND_OPTIONS << :union
    self::CALCULATIONS_OPTIONS << :union
    
    named_scope :unioned, lambda{|args|
      args.to_a.map! {|a| a.respond_to?(:scope) ? a.scope(:find) : a}
      {:union => args}
    }
  end
  
  module ClassMethods
    
    case ::ActiveRecord::VERSION::MINOR
    when 1
      def construct_finder_sql(options, scope=scope(:find))
        unless options[:union] || (scope && scope[:union])
          sql  = "SELECT #{options[:select] || (scope && scope[:select]) || ((options[:joins] || (scope && scope[:joins])) && quoted_table_name + '.*') || '*'} "
          sql << "FROM #{(scope && scope[:from]) || options[:from] || quoted_table_name} "

          add_joins!(sql, options, scope)
          add_conditions!(sql, options[:conditions], scope)
        else
          add_unions!(sql="", options, scope)
        end

        add_group!(sql, options[:group], scope)
        add_order!(sql, options[:order], scope)
        add_limit!(sql, options, scope)
        add_lock!(sql, options, scope)

        sql
      end
    when 2
      def construct_finder_sql(options, scope=scope(:find))
        unless options[:union] || (scope && scope[:union])
          sql  = "SELECT #{options[:select] || (scope && scope[:select]) || default_select(options[:joins] || (scope && scope[:joins]))} "
          sql << "FROM #{(scope && scope[:from]) || options[:from] || quoted_table_name} "

          add_joins!(sql, options[:joins], scope)
          add_conditions!(sql, options[:conditions], scope)
        else
          add_unions!(sql="", options, scope)
        end

        add_group!(sql, options[:group], scope)
        add_order!(sql, options[:order], scope)
        add_limit!(sql, options, scope)
        add_lock!(sql, options, scope)

        sql
      end
    when 3  
      def construct_finder_sql(options, scope=scope(:find))
        unless options[:union] || (scope && scope[:union])
          sql  = "SELECT #{options[:select] || (scope && scope[:select]) || default_select(options[:joins] || (scope && scope[:joins]))} "
          sql << "FROM #{options[:from]  || (scope && scope[:from]) || quoted_table_name} "

          add_joins!(sql, options[:joins], scope)
          add_conditions!(sql, options[:conditions], scope)
        else
          add_unions!(sql="", options, scope)
        end

        add_group!(sql, options[:group], options[:having], scope)
        add_order!(sql, options[:order], scope)
        add_limit!(sql, options, scope)
        add_lock!(sql, options, scope)

        sql
      end
    end

    def add_unions!(sql, options, scope)
      unions = options.delete(:union) || []
      unions += scope[:union] if scope && scope[:union]
      unions.map! do |union_options|
        conditions = [options[:conditions]]
        conditions << scope[:conditions] if scope
        conditions << union_options[:conditions]
        union_options[:conditions] = merge_conditions(*conditions)
        '(' + construct_finder_sql(union_options, nil) + ')'
      end
      sql << unions.join(' UNION ')
    end
    
  end
  
  def construct_count_options_from_args(*args)
    options     = {}
    column_name = :all
  
    # We need to handle
    #   count()
    #   count(:column_name=:all)
    #   count(options={})
    #   count(column_name=:all, options={})
    #   selects specified by scopes
    case args.size
    when 0
      column_name = scope(:find)[:select] if scope(:find)
    when 1
      if args[0].is_a?(Hash)
        column_name = scope(:find)[:select] if scope(:find)
        options = args[0]
      else
        column_name = args[0]
      end
    when 2
      column_name, options = args
    else
      raise ArgumentError, "Unexpected parameters passed to count(): #{args.inspect}"
    end
  
    [column_name || :all, options]
  end
  
  def construct_calculation_sql(operation, column_name, options) #:nodoc:
    operation = operation.to_s.downcase
    options = options.symbolize_keys
  
    scope           = scope(:find)
    merged_includes = merge_includes(scope ? scope[:include] : [], options[:include])
    aggregate_alias = column_alias_for(operation, column_name)
    column_name     = "#{connection.quote_table_name(table_name)}.#{column_name}" if column_names.include?(column_name.to_s)
  
    if operation == 'count'
      if merged_includes.any?
        options[:distinct] = true
        column_name = options[:select] || [connection.quote_table_name(table_name), primary_key] * '.'
      end
  
      if options[:distinct]
        use_workaround = !connection.supports_count_distinct?
      end
    end
  
    if options[:distinct] && column_name.to_s !~ /\s*DISTINCT\s+/i
      distinct = 'DISTINCT ' 
    end
    sql = "SELECT #{operation}(#{distinct}#{column_name}) AS #{aggregate_alias}"
  
    # A (slower) workaround if we're using a backend, like sqlite, that doesn't support COUNT DISTINCT.
    sql = "SELECT COUNT(*) AS #{aggregate_alias}" if use_workaround
  
    sql << ", #{options[:group_field]} AS #{options[:group_alias]}" if options[:group]
    
    if options[:union] || (scope && scope[:union])
      sql << " FROM ("
      add_unions!(sql, options, scope)
      sql << ") u01"
    else
      if options[:from]
        sql << " FROM #{options[:from]} "
      else
        sql << " FROM (SELECT #{distinct}#{column_name}" if use_workaround
        sql << " FROM #{connection.quote_table_name(table_name)} "
      end
  
      joins = ""
      add_joins!(joins, options[:joins], scope)
  
      if merged_includes.any?
        join_dependency = ActiveRecord::Associations::ClassMethods::JoinDependency.new(self, merged_includes, joins)
        sql << join_dependency.join_associations.collect{|join| join.association_join }.join
      end
  
      sql << joins unless joins.blank?
  
      add_conditions!(sql, options[:conditions], scope)
      add_limited_ids_condition!(sql, options, join_dependency) if join_dependency && !using_limitable_reflections?(join_dependency.reflections) && ((scope && scope[:limit]) || options[:limit])
    end
  
    if options[:group]
      group_key = connection.adapter_name == 'FrontBase' ?  :group_alias : :group_field
      sql << " GROUP BY #{options[group_key]} "
    end
  
    if options[:group] && options[:having]
      having = sanitize_sql_for_conditions(options[:having])
  
      # FrontBase requires identifiers in the HAVING clause and chokes on function calls
      if connection.adapter_name == 'FrontBase'
        having.downcase!
        having.gsub!(/#{operation}\s*\(\s*#{column_name}\s*\)/, aggregate_alias)
      end
  
      sql << " HAVING #{having} "
    end
  
    sql << " ORDER BY #{options[:order]} "       if options[:order]
    add_limit!(sql, options, scope)
    sql << ") #{aggregate_alias}_subquery" if use_workaround
    sql
  end
  
end