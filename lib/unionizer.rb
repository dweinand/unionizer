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
    
    named_scope :unioned, lambda{|*args|
      args.map! {|a| a.respond_to?(:scope) ? a.scope(:find) : a}
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
  
end