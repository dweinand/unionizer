require "rubygems"
require "active_record"
# require "active_record/version"
module Unionizer
  
  def acts_as_unionized
    extend ClassMethods
  end
  
  module ClassMethods
    
    def extended(base)
      if ::ActiveRecord::VERSION::MAJOR < 2 || ::ActiveRecord::VERSION::MINOR < 1
        raise "Not supported for versions before 2.1.0"
      end
    end

    VALID_FIND_OPTIONS = [ :conditions, :include, :joins, :limit, :offset,
                           :order, :select, :readonly, :group, :having, :from, :lock, :union ]

    # override to accept union arguments
    def validate_find_options(options) #:nodoc:
      options.assert_valid_keys(VALID_FIND_OPTIONS)
    end

    case ::ActiveRecord::VERSION::MINOR
    when 1
      def construct_finder_sql(options, scope=scope(:find))
        unless options[:union]
          sql  = "SELECT #{options[:select] || (scope && scope[:select]) || ((options[:joins] || (scope && scope[:joins])) && quoted_table_name + '.*') || '*'} "
          sql << "FROM #{(scope && scope[:from]) || options[:from] || quoted_table_name} "

          add_joins!(sql, options, scope)
          add_conditions!(sql, options[:conditions], scope)
        else
          add_unions!(sql="", options)
        end

        add_group!(sql, options[:group], scope)
        add_order!(sql, options[:order], scope)
        add_limit!(sql, options, scope)
        add_lock!(sql, options, scope)

        sql
      end
    when 2
      def construct_finder_sql(options, scope=scope(:find))
        unless options[:union]
          sql  = "SELECT #{options[:select] || (scope && scope[:select]) || default_select(options[:joins] || (scope && scope[:joins]))} "
          sql << "FROM #{(scope && scope[:from]) || options[:from] || quoted_table_name} "

          add_joins!(sql, options[:joins], scope)
          add_conditions!(sql, options[:conditions], scope)
        else
          add_unions!(sql="", options)
        end

        add_group!(sql, options[:group], scope)
        add_order!(sql, options[:order], scope)
        add_limit!(sql, options, scope)
        add_lock!(sql, options, scope)

        sql
      end
    when 3  
      def construct_finder_sql(options, scope=scope(:find))
        unless options[:union]
          sql  = "SELECT #{options[:select] || (scope && scope[:select]) || default_select(options[:joins] || (scope && scope[:joins]))} "
          sql << "FROM #{options[:from]  || (scope && scope[:from]) || quoted_table_name} "

          add_joins!(sql, options[:joins], scope)
          add_conditions!(sql, options[:conditions], scope)
        else
          add_unions!(sql="", options)
        end

        add_group!(sql, options[:group], options[:having], scope)
        add_order!(sql, options[:order], scope)
        add_limit!(sql, options, scope)
        add_lock!(sql, options, scope)

        sql
      end
    end

    def add_unions!(sql, options)
      unions = options.delete(:union)
      unions.map! do |union_options|
        union_options[:conditions] = merge_conditions(options[:conditions], union_options[:conditions])
        '(' + construct_finder_sql(union_options, {}) + ')'
      end
      sql << unions.join(' UNION ')
    end
    
  end
  
end