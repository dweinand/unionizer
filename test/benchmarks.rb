require "benchmark"
$LOAD_PATH << File.join(File.join(File.dirname(__FILE__), '..'), 'lib')
require "rubygems"
require 'mysql'
require "unionizer"
require File.join(File.join(File.dirname(__FILE__), '..'), 'init')

gem 'thoughtbot-factory_girl'
require 'factory_girl'

POSTS = 6_000
TIMES = 100

ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/benchmark.log")
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
  
  add_index 'posts', 'user_id'
  add_index 'posts', 'category_id'
  add_index 'posts', 'title'
end

class Post < ActiveRecord::Base
  acts_as_unionized
end

Factory.sequence :user_id do |n|
  (i = n % 6).zero? ? 6 : i
end

Factory.sequence :category_id do |n|
  (i = n % 6).zero? ? 6 : i
end

Factory.sequence :title do |n|
  ["Chunky Bacon", "Foo Bar"][n % 2]
end

Factory.define :post do |p|
  p.title { Factory.next(:title) } 
  p.content "Lorem ipsum dolor sit amet"
  p.user_id { Factory.next(:user_id) }
  p.category_id { Factory.next(:category_id) }
end

Post.delete_all

print "Filling database..."

POSTS.times do
  Factory(:post)
end

print "done\n"

Benchmark.bmbm do |x|
  x.report('or: ') { TIMES.times {Post.all(:conditions => ["user_id = ? OR category_id = ?", 2, 4])}}
  x.report('union: ') { TIMES.times {
    Post.all(:union => [
      {:conditions => {:user_id => 2}},
      {:conditions => {:category_id => 4}}
    ])
  }}
  x.report('union (named scope): ') { TIMES.times {
    Post.unioned(
      {:conditions => {:user_id => 2}},
      {:conditions => {:category_id => 4}}
    ).all
  }}
  x.report('union (nested named scope): ') { TIMES.times {
    Post.unioned(
      Post.scoped({:conditions => {:user_id => 2}}),
      Post.scoped({:conditions => {:category_id => 4}})
    ).all
  }}
  x.report('or (naked):') { TIMES.times {
    Post.find_by_sql(["select * from posts where user_id = ? OR category_id = ?", 2, 4])
  }}
  x.report('union (naked): ') { TIMES.times {
    Post.find_by_sql([%{select * from posts where user_id = ? union select * from posts where category_id = ?}, 2, 4])
  }}
  x.report('or (where): ') { TIMES.times {
    Post.all(:conditions => ["(user_id = ? OR category_id = ?) and title = ?", 2, 4, "Chunky Bacon"])
  }}
  x.report('union (where): ') { TIMES.times {
    Post.all(:union => [
      {:conditions => {:user_id => 2}},
      {:conditions => {:category_id => 4}},
    ], :conditions => {:title => 'Chunky Bacon'})
  }}
end


Post.delete_all