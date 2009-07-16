$LOAD_PATH << File.join(File.join(File.dirname(__FILE__), '..'), 'lib')
require 'rubygems'
require 'test/unit'

gem 'sqlite3-ruby'
 
require 'active_support'
require 'active_support/test_case'
require 'active_record'

gem 'thoughtbot-factory_girl'
require 'factory_girl'

require "unionizer"
require "../init"

ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
ActiveRecord::Base.establish_connection({
  :adapter => 'mysql',
  :database => 'unionizer_test',
  :user => 'root'
})

ActiveRecord::Schema.define do
  create_table "posts", :force => true do |t|
    t.string "title"
    t.text "content"
    t.integer "user_id"
    t.integer "category_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end
end

class Post < ActiveRecord::Base
  acts_as_unionized
  
  named_scope :recent, {:order => 'category_id DESC'}
  named_scope :oldest, {:order => 'category_id ASC'}
  named_scope :latest, {:limit => 1}
  named_scope :with_user_id, lambda {|id| {:conditions => {:user_id => id}}}
  named_scope :with_category_id, lambda {|id| {:conditions => {:category_id => id}}}
  named_scope :scope_with_union, lambda {|u,c| {:union => [
    {:conditions => {:user_id => u}},
    {:conditions => {:category_id => c}}
  ]}}
  named_scope :with_category, {:conditions => 'category_id is not null'}
end

Factory.sequence :title do |n|
  "Post #{n}"
end

Factory.sequence :user_id do |n|
  n
end

Factory.sequence :category_id do |n|
  2 * n
end

Factory.define :post do |p|
  p.title { Factory.next(:title) }
  p.content "Lorem ipsum dolor sit amet"
  p.user_id { Factory.next(:user_id) }
  p.category_id { Factory.next(:category_id) }
end

class ActiveSupport::TestCase
  # Taken from shoulda
  def assert_same_elements(a1, a2, msg = nil)
    [:select, :inject, :size].each do |m|
      [a1, a2].each {|a| assert_respond_to(a, m, "Are you sure that #{a.inspect} is an array?  It doesn't respond to #{m}.") }
    end

    assert a1h = a1.inject({}) { |h,e| h[e] = a1.select { |i| i == e }.size; h }
    assert a2h = a2.inject({}) { |h,e| h[e] = a2.select { |i| i == e }.size; h }

    assert_equal(a1h, a2h, msg)
  end
end
